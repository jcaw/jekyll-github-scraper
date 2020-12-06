# Jekyll Github Contributions Scraper

Jekyll generator plugin that gets details of all your open source contributions from the GitHub GraphQL API. The most important information that's pulled is every project you've contributed to (including your own), with the volume of your contributions.

You can use this information to create a portfolio on your Jekyll site. Put it in a table and you have a summary of all your open-source experience, that updates automatically. Your most recent pull requests (with diff counts) are also pulled in case you'd like to display them as a feed.

The information is all saved as JSON in your `_data` folder, so it's accessible from liquid templates.

This is done as a generator rather than with client-side Javascript because the Github v4 API requires authentication and limits requests.

## Install

* Add the repo as a git source to your Jekyll Gemfile: 
  ```Gemfile
  gem "jekyll-github-scraper", git: "https://github.com/jcaw/jekyll-github-scraper"
  ```
* Add `jekyll-github-scraper` to the gems list within your Jekyll site's `_config.yml`
<!-- ^ TODO: Is this still necessary? -->

## Usage

Add the following to `_config.yml` and adjust as desired:

```yml
githubcontributions:
  # GitHub username
  username: jcaw
  # Number of seconds to cache the data file
  cache: 300
  # Optional - pass this to override & get contributions from before you joined 
  # (or ignore early years)
  # start_year: 2018
```

You will also need to set the environment variable `API_TOKEN_GITHUB` to an API key with repository read rights before building your site.

If you don't want to hammer the API every time you build, set `cache` and new results will only be queried after that period.

To update your contributions automatically, you might want to set up a manual GitHub Action that builds your site and set it to run nightly. Manually configured actions do allow arbitrary plugins.

## Displaying Results

TODO: I'd like to include some boilerplate examples displaying the information that's pulled, but for now just make table and iterate over every contribution, inserting a row with the information you want for each repo. 
