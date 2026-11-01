# frozen_string_literal: true

require "dry/cli"
require "dry/cli/help"
require "dry/cli/ui"
require "dry/cli/autocomplete/command"
require "zeitwerk"

module LLM
  module Evals
    class Error < StandardError; end
  end
end

loader = Zeitwerk::Loader.for_gem_extension(LLM)
loader.inflector.inflect("evals" => "Evals", "cli" => "CLI", "llm" => "LLM")
loader.setup
