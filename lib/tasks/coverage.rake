# frozen_string_literal: true

namespace :coverage do
  desc 'Run tests and open coverage report'
  task :open do
    system('rspec')
    system('open coverage/index.html') # macOS
  end
end
