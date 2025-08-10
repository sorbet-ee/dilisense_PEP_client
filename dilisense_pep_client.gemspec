# frozen_string_literal: true

require_relative "lib/dilisense_pep_client/version"

Gem::Specification.new do |spec|
  spec.name = "dilisense_pep_client"
  spec.version = DilisensePepClient::VERSION
  spec.authors = ["Sorbeet Payments OU"]
  spec.email = ["angelos@sorbet.ee"]

  spec.summary = "Enterprise Ruby client for Dilisense PEP and sanctions screening API"
  spec.description = "Industrial-grade Ruby client for Dilisense's PEP (Politically Exposed Persons) and sanctions screening API. Designed for Estonian financial institutions and FinTech companies requiring AML/KYC compliance with comprehensive error handling, audit logging, and security features."
  spec.homepage = "https://github.com/sorbet-ee/dilisense_PEP_client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sorbet-ee/dilisense_PEP_client"
  spec.metadata["changelog_uri"] = "https://github.com/sorbet-ee/dilisense_PEP_client/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "dotenv", "~> 2.0"
  spec.add_dependency "semantic_logger", "~> 4.0"
  spec.add_dependency "dry-validation", "~> 1.10"
  spec.add_dependency "concurrent-ruby", "~> 1.2"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "rubocop-minitest", "~> 0.31"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "simplecov", "~> 0.21"
end