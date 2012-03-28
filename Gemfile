source 'http://rubygems.org'

gem 'activerecord', '>= 3.2', :require => 'active_record'

group :test do
  gem 'autotest'
  gem 'database_cleaner', '>= 0.7'
  gem 'fuubar'
  gem 'pg', '>= 0.11'
  gem 'rspec', rspec_version = '>= 2.6'
  gem 'simplecov', :require => false
  if RUBY_PLATFORM =~ /darwin/
    gem 'autotest-fsevent', '>= 0.2'
    gem 'autotest-growl', '>= 0.2'
  end
end
