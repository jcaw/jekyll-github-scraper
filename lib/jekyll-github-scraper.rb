require 'jekyll'
require 'net/http'
require 'json'
require 'graphql/client'
require 'graphql/client/http'


module Jekyll
  TOKEN = ENV["API_TOKEN_GITHUB"] || ""
  if TOKEN == "" then
    warn "WARNING: No API key provided - cannot query GitHub API without a valid key. Please set the environment variable `API_TOKEN_GITHUB` before the Jekyll build."
  else
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
      CONTRIBUTIONS_KEY = 'github-contributions'.freeze
      SOURCES_KEY       = 'github-sources'.freeze
      RECENT_PRS_KEY    = 'github-recent-merged-prs'.freeze

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
              pullRequestContributionsByRepository(maxRepositories: 100) {
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

      def remove_emojis(str)
        # Adapted from method by Mohammad Mahmoodi: https://gist.github.com/mm580486/8102d3622ee5ec7e150b35923e9a69f7
        #
        # Updated regex by Guanting Chen: https://github.com/guanting112/remove_emoji/blob/5a8c8c74215e6d690683d2332a50e6e8a46d3ad1/lib/remove_emoji/rules.rb
        #
        # This will strip a lot of other characters too, *including Chinese.*
		    str=str.dup.force_encoding('utf-8').encode
		    regex = /[\uFE00-\uFE0F\u203C\u2049\u2122\u2139\u2194-\u2199\u21A9-\u21AA\u231A-\u231B\u2328\u23CF\u23E9-\u23F3\u23F8-\u23FA\u24C2\u25AA-\u25AB\u25B6\u25C0\u25FB-\u25FE\u2600-\u2604\u260E\u2611\u2614-\u2615\u2618\u261D\u2620\u2622-\u2623\u2626\u262A\u262E-\u262F\u2638-\u263A\u2640\u2642\u2648-\u2653\u2660\u2663\u2665-\u2666\u2668\u267B\u267E-\u267F\u2692-\u2697\u2699\u269B-\u269C\u26A0-\u26A1\u26AA-\u26AB\u26B0-\u26B1\u26BD-\u26BE\u26C4-\u26C5\u26C8\u26CE\u26CF\u26D1\u26D3-\u26D4\u26E9-\u26EA\u26F0-\u26F5\u26F7-\u26FA\u26FD\u2702\u2705\u2708-\u2709\u270A-\u270B\u270C-\u270D\u270F\u2712\u2714\u2716\u271D\u2721\u2728\u2733-\u2734\u2744\u2747\u274C\u274E\u2753-\u2755\u2757\u2763-\u2764\u2795-\u2797\u27A1\u27B0\u27BF\u2934-\u2935\u2B05-\u2B07\u2B1B-\u2B1C\u2B50\u2B55\u3030\u303D\u3297\u3299\u{1F004}\u{1F0CF}\u{1F170}-\u{1F171}\u{1F17E}\u{1F17F}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E6}-\u{1F1FF}\u{1F201}-\u{1F202}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}-\u{1F251}\u{1F300}-\u{1F320}\u{1F321}\u{1F324}-\u{1F32C}\u{1F32D}-\u{1F32F}\u{1F330}-\u{1F335}\u{1F336}\u{1F337}-\u{1F37C}\u{1F37D}\u{1F37E}-\u{1F37F}\u{1F380}-\u{1F393}\u{1F396}-\u{1F397}\u{1F399}-\u{1F39B}\u{1F39E}-\u{1F39F}\u{1F3A0}-\u{1F3C4}\u{1F3C5}\u{1F3C6}-\u{1F3CA}\u{1F3CB}-\u{1F3CE}\u{1F3CF}-\u{1F3D3}\u{1F3D4}-\u{1F3DF}\u{1F3E0}-\u{1F3F0}\u{1F3F3}-\u{1F3F5}\u{1F3F7}\u{1F3F8}-\u{1F3FF}\u{1F400}-\u{1F43E}\u{1F43F}\u{1F440}\u{1F441}\u{1F442}-\u{1F4F7}\u{1F4F8}\u{1F4F9}-\u{1F4FC}\u{1F4FD}\u{1F4FF}\u{1F500}-\u{1F53D}\u{1F549}-\u{1F54A}\u{1F54B}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F56F}-\u{1F570}\u{1F573}-\u{1F579}\u{1F57A}\u{1F587}\u{1F58A}-\u{1F58D}\u{1F590}\u{1F595}-\u{1F596}\u{1F5A4}\u{1F5A5}\u{1F5A8}\u{1F5B1}-\u{1F5B2}\u{1F5BC}\u{1F5C2}-\u{1F5C4}\u{1F5D1}-\u{1F5D3}\u{1F5DC}-\u{1F5DE}\u{1F5E1}\u{1F5E3}\u{1F5E8}\u{1F5EF}\u{1F5F3}\u{1F5FA}\u{1F5FB}-\u{1F5FF}\u{1F600}\u{1F601}-\u{1F610}\u{1F611}\u{1F612}-\u{1F614}\u{1F615}\u{1F616}\u{1F617}\u{1F618}\u{1F619}\u{1F61A}\u{1F61B}\u{1F61C}-\u{1F61E}\u{1F61F}\u{1F620}-\u{1F625}\u{1F626}-\u{1F627}\u{1F628}-\u{1F62B}\u{1F62C}\u{1F62D}\u{1F62E}-\u{1F62F}\u{1F630}-\u{1F633}\u{1F634}\u{1F635}-\u{1F640}\u{1F641}-\u{1F642}\u{1F643}-\u{1F644}\u{1F645}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CB}-\u{1F6CF}\u{1F6D0}\u{1F6D1}-\u{1F6D2}\u{1F6E0}-\u{1F6E5}\u{1F6E9}\u{1F6EB}-\u{1F6EC}\u{1F6F0}\u{1F6F3}\u{1F6F4}-\u{1F6F6}\u{1F6F7}-\u{1F6F8}\u{1F6F9}\u{1F910}-\u{1F918}\u{1F919}-\u{1F91E}\u{1F91F}\u{1F920}-\u{1F927}\u{1F928}-\u{1F92F}\u{1F930}\u{1F931}-\u{1F932}\u{1F933}-\u{1F93A}\u{1F93C}-\u{1F93E}\u{1F940}-\u{1F945}\u{1F947}-\u{1F94B}\u{1F94C}\u{1F94D}-\u{1F94F}\u{1F950}-\u{1F95E}\u{1F95F}-\u{1F96B}\u{1F96C}-\u{1F970}\u{1F973}-\u{1F976}\u{1F97A}\u{1F97C}-\u{1F97F}\u{1F980}-\u{1F984}\u{1F985}-\u{1F991}\u{1F992}-\u{1F997}\u{1F998}-\u{1F9A2}\u{1F9B0}-\u{1F9B9}\u{1F9C0}\u{1F9C1}-\u{1F9C2}\u{1F9D0}-\u{1F9E6}\u{1F9E7}-\u{1F9FF}\u23E9-\u23EC\u23F0\u23F3\u25FD-\u25FE\u267F\u2693\u26A1\u26D4\u26EA\u26F2-\u26F3\u26F5\u26FA\u{1F201}\u{1F232}-\u{1F236}\u{1F238}-\u{1F23A}\u{1F3F4}\u{1F6CC}\u{1F3FB}-\u{1F3FF}\u26F9\u{1F385}\u{1F3C2}-\u{1F3C4}\u{1F3C7}\u{1F3CA}\u{1F3CB}-\u{1F3CC}\u{1F442}-\u{1F443}\u{1F446}-\u{1F450}\u{1F466}-\u{1F469}\u{1F46E}\u{1F470}-\u{1F478}\u{1F47C}\u{1F481}-\u{1F483}\u{1F485}-\u{1F487}\u{1F4AA}\u{1F574}-\u{1F575}\u{1F645}-\u{1F647}\u{1F64B}-\u{1F64F}\u{1F6A3}\u{1F6B4}-\u{1F6B6}\u{1F6C0}\u{1F918}\u{1F919}-\u{1F91C}\u{1F91E}\u{1F926}\u{1F933}-\u{1F939}\u{1F93D}-\u{1F93E}\u{1F9B5}-\u{1F9B6}\u{1F9D1}-\u{1F9DD}\u200D\u20E3\uFE0F\u{1F9B0}-\u{1F9B3}\u{E0020}-\u{E007F}\u2388\u2600-\u2605\u2607-\u2612\u2616-\u2617\u2619\u261A-\u266F\u2670-\u2671\u2672-\u267D\u2680-\u2689\u268A-\u2691\u2692-\u269C\u269D\u269E-\u269F\u26A2-\u26B1\u26B2\u26B3-\u26BC\u26BD-\u26BF\u26C0-\u26C3\u26C4-\u26CD\u26CF-\u26E1\u26E2\u26E3\u26E4-\u26E7\u26E8-\u26FF\u2700\u2701-\u2704\u270C-\u2712\u2763-\u2767\u{1F000}-\u{1F02B}\u{1F02C}-\u{1F02F}\u{1F030}-\u{1F093}\u{1F094}-\u{1F09F}\u{1F0A0}-\u{1F0AE}\u{1F0AF}-\u{1F0B0}\u{1F0B1}-\u{1F0BE}\u{1F0BF}\u{1F0C0}\u{1F0C1}-\u{1F0CF}\u{1F0D0}\u{1F0D1}-\u{1F0DF}\u{1F0E0}-\u{1F0F5}\u{1F0F6}-\u{1F0FF}\u{1F10D}-\u{1F10F}\u{1F12F}\u{1F16C}-\u{1F16F}\u{1F1AD}-\u{1F1E5}\u{1F203}-\u{1F20F}\u{1F23C}-\u{1F23F}\u{1F249}-\u{1F24F}\u{1F252}-\u{1F25F}\u{1F260}-\u{1F265}\u{1F266}-\u{1F2FF}\u{1F321}-\u{1F32C}\u{1F394}-\u{1F39F}\u{1F3F1}-\u{1F3F7}\u{1F3F8}-\u{1F3FA}\u{1F4FD}-\u{1F4FE}\u{1F53E}-\u{1F53F}\u{1F540}-\u{1F543}\u{1F544}-\u{1F54A}\u{1F54B}-\u{1F54F}\u{1F568}-\u{1F579}\u{1F57B}-\u{1F5A3}\u{1F5A5}-\u{1F5FA}\u{1F6C6}-\u{1F6CF}\u{1F6D3}-\u{1F6D4}\u{1F6D5}-\u{1F6DF}\u{1F6E0}-\u{1F6EC}\u{1F6ED}-\u{1F6EF}\u{1F6F0}-\u{1F6F3}\u{1F6F9}-\u{1F6FF}\u{1F774}-\u{1F77F}\u{1F7D5}-\u{1F7FF}\u{1F80C}-\u{1F80F}\u{1F848}-\u{1F84F}\u{1F85A}-\u{1F85F}\u{1F888}-\u{1F88F}\u{1F8AE}-\u{1F8FF}\u{1F900}-\u{1F90B}\u{1F90C}-\u{1F90F}\u{1F93F}\u{1F96C}-\u{1F97F}\u{1F998}-\u{1F9BF}\u{1F9C1}-\u{1F9CF}\u{1F9E7}-\u{1FFFD}]/x
        # TODO: Remove double spaces and strip?
		    return str.gsub regex, ''
	    end

      def data_dir(site)
        # TODO: test `data_source` here works
        return site.source["data_source"] || File.join(site.source, site.config["data_dir"])
      end

      def data_file(site, key)
        return File.join(data_dir(site), "#{key}.json")
      end

      # Stores `value` under `key` in site.data, and writes a json cache for
      # future builds.
      def store_data(site, key, value)
        Jekyll.logger.info "  Storing #{key}"
        site.data[key] = value
        dir = data_dir(site)
        Dir.mkdir(dir) unless Dir.exist?(dir)
        File.write(data_file(site, key), value.to_json)
      end

      # Array copy with all members duplicated
      def dup_members(array)
        out = []
        for item in array do
          out.append(item.dup)
        end
        return out
      end

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
        for filename in [data_file(site, CONTRIBUTIONS_KEY), data_file(site, SOURCES_KEY), data_file(site, RECENT_PRS_KEY)] do
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

          collection = user['contributionsCollection']
          commits = dup_members(collection['commitContributionsByRepository'])
          prs = dup_members(collection['pullRequestContributionsByRepository'])
          # Add some meta information to differentiate seemingly identical
          # contributions.
          for commit in commits do
            commit['type'] = 'commit'
          end
          for pr in prs do
            pr['type'] = 'pr'
          end

          for datum in commits + prs do
            repo = datum['repository']
            owner = repo['owner']['login']
            repo_name = repo['name']
            # TODO: swap `full_name` over to `nameWithOwner`
            full_name = '%s/%s' % [owner, repo_name]
            contribution_count = datum['contributions']['totalCount']
            # HACK: O(n^2) with this comparison method, but that's fine
            if pr_repos.include? datum then
              # It's a PR contribution
              commit_count = 0
              pr_count = contribution_count
            else
              # It's a commit contribution
              commit_count = contribution_count
              pr_count = 0
            end

            if contributions.assoc(full_name) then
              info = contributions[full_name]
              info['n_commits'] += commit_count
              info['n_prs'] += pr_count
            elsif sources.assoc(full_name) then
              info = sources[full_name]
              info['n_commits'] += commit_count
              info['n_prs'] += pr_count
            else
              info = repo.dup
              info['full_name'] = full_name
              info['n_commits'] = commit_count
              info['n_prs'] = pr_count
              info['description_no_emojis'] = remove_emojis(info['description'])
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

          # Remove repos that only have PRs but no commits. We just assume the
          # user hasn't had any contributions accepted (yet) in these repos.
          contributions.delete_if{|k,c| c['n_commits'] == 0}


          if year == current_year then
            # TODO: Maybe get the most recent 100, then gather 10 from that (so I
            #   can ignore PRs against my own repositories).
            recent_merged_prs = user['pullRequests']['nodes']
          end

          year -= 1
        end

        #######################################################################

        unless commits.nil? and prs.nil? then
          store_data(site, CONTRIBUTIONS_KEY, contributions.values)
          store_data(site, SOURCES_KEY, sources.values)
        end
        unless recent_merged_prs.nil? then
          store_data(site, RECENT_PRS_KEY, recent_merged_prs)
        end
      end
    end
  end
end
