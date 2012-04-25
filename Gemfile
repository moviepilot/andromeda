source "http://rubygems.org"

gem 'json', '>=1.6.5'
gem 'threadpool'
gem 'facter'
gem 'atomic'

group :development do
  gem 'rake'
  gem 'yard'
  gem 'irbtools'
end

group :test do
  gem 'rspec', '2.6.0'
  gem 'simplecov'
end

platforms :jruby do
  gem 'maruku'
end

platforms :mingw do
  gem 'maruku'
end

platforms :ruby do
  gem 'redcarpet'
end
