# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "yard"
YARD::Rake::YardocTask.new

task build: [:date_epoch, :parlour]

desc "Set SOURCE_DATE_EPOCH"
task :date_epoch do
  ENV["SOURCE_DATE_EPOCH"] = IO.popen(%W[git -C #{__dir__} log -1 --format=%ct], &:read).chomp
end

desc "Generate RBI"
task :parlour do
  system("bundle exec parlour") || abort
end

task default: :build
