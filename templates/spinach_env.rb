ENV['RAILS_ENV'] = 'test'
require './config/environment'
require 'database_cleaner'

require 'rspec/rails'
require 'capybara-webkit'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
end

ActiveRecord::Migration.maintain_test_schema!

DatabaseCleaner.strategy = :transaction

Spinach.hooks.before_run do
  DatabaseCleaner.clean_with(:deletion)
end

Spinach.hooks.before_scenario do
  DatabaseCleaner.start
end

Spinach.hooks.after_scenario do
  DatabaseCleaner.clean
end

Spinach.config.save_and_open_page_on_failure = true
