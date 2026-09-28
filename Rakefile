# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :package do
  allowed_gem_files = [
    %r{\Alib/.+\.rb\z},
    %r{\Asig/.+\.rbs\z},
    /\AREADME\.md\z/,
    /\ALICENSE\.txt\z/,
    /\ACHANGELOG\.md\z/
  ].freeze

  desc "Fail if the gem would ship any file outside the allow-list"
  task :check do
    spec = Gem::Specification.load("cashfree_pg.gemspec")
    unexpected = spec.files.reject { |f| allowed_gem_files.any? { |pattern| pattern.match?(f) } }

    abort "Files not allowed in the gem package:\n  #{unexpected.join("\n  ")}" if unexpected.any?

    puts "Gem package contents OK (#{spec.files.size} files)"
  end
end

desc "Validate RBS signatures in sig/"
task :rbs do
  sh "rbs", "-I", "sig", "validate"
end

task default: %i[spec rubocop rbs package:check]
