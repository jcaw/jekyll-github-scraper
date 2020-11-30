require 'jekyll'
require 'net/http'
require 'json'
require 'graphql/client'
require 'graphql/client/http'


module Jekyll
  TOKEN = ENV["API_TOKEN_GITHUB"]
  if TOKEN == nil or TOKEN == "" then
    raise "No API key provided - cannot query GitHub API without a valid key. Please set the environment variable `API_TOKEN_GITHUB` before the Jekyll build."
  end

  HTTP = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(context)
      { "Authorization" => "Bearer #{TOKEN}" }
    end
  end

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, 'path/to/schema.json')
  #
  # Schema = GraphQL::Client.load_schema('path/to/schema.json')

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  # Generates a github contributions data file
  class GithubContributionsGenerator < Jekyll::Generator
    CONTRIBUTIONS_FILE = '_data/github-contributions.json'.freeze
    SOURCES_FILE = '_data/github-sources.json'.freeze
    RECENT_PRS_FILE = '_data/recent-merged-prs.json'.freeze

    CONTRIBUTIONS_QUERY = Client.parse <<-'GRAPHQL'
      query($start_date: DateTime, $end_date: DateTime, $login: String!) {
        user(login: $login) {
          createdAt
          # We only need to get the pull requests once, but it costs no more
          # API tokens to bundle here so just throw it into every request.
          pullRequests (first: 10, states: [MERGED],
                        orderBy: { field:UPDATED_AT, direction:DESC }) {
            nodes {
              title
              repository {
                name
                owner {
                  login
                }
                nameWithOwner
              }
              additions
              deletions
              url
            }
          }
          contributionsCollection(from: $start_date, to: $end_date) {
            # TODO: What if there's a higher number of maxRepositories than 100? We need to paginate.
            commitContributionsByRepository(maxRepositories: 100) {
              repository {
                owner {
                  login
                }
                name
                nameWithOwner
                url
                description
                languages(first:100) {
                  nodes {
                    color
                    name
                  }
                }
              }
              contributions {
                totalCount
              }
            }
          }
        }
      }
    GRAPHQL

    # TODO: Consistent strings
    def generate(site)
      settings = {
        'cache' => 300,
        'username' => 'PASS_YOUR_USERNAME',
        # You can pass 'start_year' to override the automatic limit of join date
        # (for example, to get commits made before you had a GitHub account).
      }.merge(site.config['githubcontributions'])

      # TODO: Maybe query all the files?
      cache_valid = true
      for filename in [CONTRIBUTIONS_FILE, SOURCES_FILE, RECENT_PRS_FILE] do
        if !(File.exist?(filename) && (File.mtime(filename) + settings['cache']) > Time.now) then
          cache_valid = false
          break
        end
      end
      if cache_valid then
        Jekyll.logger.info 'Using cached GitHub contributions'
        return
      end
      Jekyll.logger.info 'Querying Github for contributions'

      year = current_year = Time.now.year
      username = settings['username']
      # We only want to get records from years the user was a member. If no
      # override is provided, this will be determined from the first query.
      earliest_year = settings['start_year'] || -1
      contributions = {}
      sources = {}
      while year >= earliest_year
        Jekyll.logger.info('  Fetching year: %s' % year)
        start_date = '%s-01-01T00:00:00' % [year]
        end_date   = '%s-01-01T00:00:00' % [year + 1]
        # TODO: Paginated results - what if there's >100 repos?
        result = Client.query(CONTRIBUTIONS_QUERY, variables: { start_date: start_date,
                                                                end_date: end_date,
                                                                login: username, })
        data = result.data.to_h
        # TODO: If there's an error, stop & send an email
        # https://github.com/github/graphql-client/blob/master/guides/handling-errors.md

        user = data['user']

        if earliest_year == -1 then
          earliest_year = user['createdAt'].split('-')[0].to_i
          Jekyll.logger.info '  User joined in %s - querying back to the start of %s' % [earliest_year, earliest_year]
        end

        repos = user['contributionsCollection']['commitContributionsByRepository']

        for datum in repos do
          repo = datum['repository']
          owner = repo['owner']['login']
          repo_name = repo['name']
          # TODO: swap `full_name` over to `nameWithOwner`
          full_name = '%s/%s' % [owner, repo_name]
          count = datum['contributions']['totalCount']
          if contributions.assoc(full_name) then
            contributions[full_name]['n_commits'] += count
          elsif sources.assoc(full_name) then
            sources[full_name]['n_commits'] += count
          else
            info = repo.dup
            info['full_name'] = full_name
            info['n_commits'] = count
            # URL to view all PRs from `username`. We don't restrict to just
            # merged PRs because some projects don't merge directly - they close
            # & cherry-pick the commits.
            url = repo['url']
            info['my_pulls_url'] = '%s/pulls?q=author%%3A%s' % [url, username]
            info['my_commits_url'] = '%s/commits?author=%s' % [url, username]
            # TODO: Maybe a list of all my commits? E.g. for projects with a
            #   different PR structure.
            if owner.downcase.eql? username.downcase then
              sources[full_name] = info
            else
              contributions[full_name] = info
            end
          end
        end

        if year == current_year then
          # TODO: Maybe get the most recent 100, then gather 10 from that (so I
          #   can ignore PRs against my own repositories).
          recent_merged_prs = user['pullRequests']['nodes']
        end

        year -= 1
      end

      #######################################################################

      Dir.mkdir('_data') unless Dir.exist?('_data')
      unless repos.nil? then
        Jekyll.logger.info '  Saving contributions'
        File.write(CONTRIBUTIONS_FILE, contributions.values.to_json)
        Jekyll.logger.info '  Saving sources'
        File.write(SOURCES_FILE, sources.values.to_json)
      end
      unless recent_merged_prs.nil? then
        Jekyll.logger.info '  Saving recent PRs'
        File.write(RECENT_PRS_FILE, recent_merged_prs.to_json)
      end
    end
  end
end
