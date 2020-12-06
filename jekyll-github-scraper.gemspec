Gem::Specification.new do |s|
  s.name        = 'jekyll-github-scraper'
  s.version     = '0.1.1'
  s.summary     = "Jekyll plugin that automatically pulls the projects you've contributed to from GitHub"
  s.description = File.read('README.md')
  s.license     = 'Apache 2'
  s.authors     = ['Jesse Cotton', 'Jcaw']
  s.email       = ['jcotton1123@gmail.com', 'toastedjcaw@gmail.com']
  s.files       = [*Dir['lib/**/*.rb'], 'README.md', 'LICENSE']
  s.homepage    = 'https://github.com/jcaw/jekyll-github-scraper'

  s.add_runtime_dependency 'jekyll', '~> 4.0'
  s.add_runtime_dependency 'graphql-client'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubocop'
end
