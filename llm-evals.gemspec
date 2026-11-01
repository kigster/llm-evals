# frozen_string_literal: true

require_relative "lib/llm/evals/version"

Gem::Specification.new do |spec|
  spec.name = "llm-evals"
  spec.version = LLM::Evals::VERSION
  spec.authors = ["Konstantin Gredeskoul"]
  spec.email = ["kigster@gmail.com"]

  spec.summary = "This is a flexible CLI framework for running suites of LLM evaluation tasks against datasets, which may have multiple cases. A generic evaluation runner for LLM-backed code: adapters run, scorers score, the CLI reports"
  spec.description = "It works with any model via OpenRouter, and has a direct adapter for Jev.  You can use it to compare how various models perform on an important in your application task or how an expression that uses the same model changes over time as you tweak it's parameters or prompts."
  spec.homepage = "https://github.com/kigster/llm-evals"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kigster/llm-evals"
  spec.metadata["changelog_uri"] = "https://github.com/kigster/llm-evals/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dotenv", "~> 3.2"
  spec.add_dependency "dry-cli", "~> 1.4"
  spec.add_dependency "dry-cli-autocomplete", "~> 0.6"
  spec.add_dependency "dry-cli-help", "~> 0.6"
  spec.add_dependency "dry-cli-ui", "~> 0.7"
  spec.add_dependency "zeitwerk", "~> 2.8"

  # Already in the bundle through dry-cli-ui; named because the CLI draws its
  # own right-aligned tables and colored status boxes with them.
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "ruby_llm", "~> 2.1"
  spec.add_dependency "tty-box", "~> 0.7"
  spec.add_dependency "tty-table", "~> 0.12"

  # Bundled gems since Ruby 3.5 are not loadable under Bundler unless declared;
  # Warnings builds a Logger, so a consumer without this line would raise LoadError.
  spec.add_dependency "logger", "~> 1.6"

  # Braintrust is deliberately not a runtime dependency: local runs and suites
  # that choose another tracker never load it. The tracker command requires it
  # lazily and names the gem when it is missing.
end
