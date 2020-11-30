# Jekyll Github Contributions Plugin

Jekyll generator plugin that generates a Github contributions data file.

Why do this via a generator instead of with Javascript? The Github API rate limits API requests.

## Install

* Add the repo as a git source to your Jekyll Gemfile: 
```Gemfile
gem "jekyll-github-contributions", git: "https://github.com/jcaw/jekyll-github-contributions"
```
* Add `jekyll-github-contributions` to the gems list within your Jekyll site's `_config.yml`

## Config

Add the following to `_config.yml` and adjust as desired:

```yml
githubcontributions:
  username: jcaw # Github username
  cache: 300 # Number of seconds to cache the data file
  # Optional - pass this to override & get contributions from before you joined 
  # (or ignore early years)
  # start_year: 2018
```

## Usage

*TODO*
