# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.7'

# Core
gem 'pg', '~> 1.5'
gem 'puma', '>= 5.0'
gem 'rails', '~> 7.1.0'

# Authentication
gem 'bcrypt', '~> 3.1.7'
gem 'jwt', '~> 2.7'

# API & Serialization
gem 'jbuilder', '~> 2.11'
gem 'rack-cors', '~> 2.0'

# Background Jobs
gem 'redis', '>= 4.0.1'
gem 'sidekiq', '~> 7.1'

# File Uploads
gem 'aws-sdk-s3', '~> 1.136'
gem 'image_processing', '~> 1.12'

# Pagination
gem 'kaminari', '~> 1.2'

# Environment Variables
gem 'dotenv-rails', groups: %i[development test]

# Timezone data for Windows
gem 'tzinfo-data', platforms: %i[windows jruby]

# Performance
gem 'bootsnap', require: false

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.2'
  gem 'pry-rails'
  gem 'rspec-rails', '~> 6.0'
end

group :development do
  gem 'annotate', '~> 3.2'
  gem 'rubocop-rails', require: false
end

group :test do
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'shoulda-matchers', '~> 5.3'
end
