# frozen_string_literal: true

module LLM
  module Evals
    # Every command the executable answers to.
    module CLI
      extend Dry::CLI::Registry

      Dry::CLI::Help.configure do
        title "Evals"
        description "A flexible CLI framework for running LLM evaluation suites, which integrates with paid Eval Products, such as Braintrust"

        columns = IO.console&.winsize&.last || 80
        width [columns - 6, 120].min
        exit_code_without_arguments 0

        styles do
          heading :bold, :cyan, case: :UPPERCASE
          usage :yellow
          example :yellow
          option :green
          example_comment :bright_black
        end
      end

      register "demo", Demo
      register "version", Version, aliases: ["-V", "--version"]
      register "completion", Dry::CLI::Autocomplete::Command[self, program_name: "evals"]
    end
  end
end
