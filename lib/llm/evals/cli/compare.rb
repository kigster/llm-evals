# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Several models at one setting, side by side: one experiment each,
      # with either a terminal leaderboard or a saved HTML/JSON report.
      class Compare < ModelCommand
        desc "Run every case against several models and report the results"

        example [
          "                                     # everything .llm-evals.config.yml lists",
          "-m anthropic/claude-haiku-5.5,openai/gpt-4o-mini -t 0",
          "-e low -c clear -j 2                 # two experiments at a time",
          "-n                                   # show the matrix, spend nothing"
        ]
      end
    end
  end
end
