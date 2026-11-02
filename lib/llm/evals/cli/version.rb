# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # `evals version`, also reachable as -V and --version.
      class Version < Command
        desc "Print the version"

        # Prints the bare number, so a script can read it.
        #
        # @return [void]
        def call(**)
          out.puts LLM::Evals::VERSION
        end
      end
    end
  end
end
