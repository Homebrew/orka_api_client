# frozen_string_literal: true

require_relative "lib/orka_api_client/version"

Gem::Specification.new do |spec|
  spec.name = "orka_api_client"
  spec.version = OrkaAPI::Client::VERSION
  spec.authors = ["Bo Anderson"]
  spec.email = ["mail@boanderson.me"]

  spec.summary = "Ruby library for interfacing with the MacStadium Orka API."
  spec.homepage = "https://github.com/Homebrew/orka_api_client"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Homebrew/orka_api_client"
  spec.metadata["bug_tracker_uri"] = "https://github.com/Homebrew/orka_api_client/issues"
  spec.metadata["changelog_uri"] = "https://github.com/Homebrew/orka_api_client/releases/tag/#{spec.version}"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    (Dir.glob("*.{md,txt}") + Dir.glob("{exe,lib,rbi}/**/*")).reject { |f| File.directory?(f) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
end
