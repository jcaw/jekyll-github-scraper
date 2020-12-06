# Jekyll Github Contributions Scraper

Jekyll generator plugin that generates a Github contributions data file.

Why do this via a generator instead of with Javascript? The Github API rate limits API requests.

## Install

* Add the repo as a git source to your Jekyll Gemfile: 
  ```Gemfile
  gem "jekyll-github-scraper", git: "https://github.com/jcaw/jekyll-github-scraper"
  ```
* Add `jekyll-github-scraper` to the gems list within your Jekyll site's `_config.yml`
<!-- ^ TODO: Is this still necessary? -->

## Config

Add the following to `_config.yml` and adjust as desired:

```yml
githubcontributions:
  # Github username
  username: jcaw
  # Number of seconds to cache the data file
  cache: 300
  # Optional - pass this to override & get contributions from before you joined 
  # (or ignore early years)
  # start_year: 2018
```

## Usage

To add later.
