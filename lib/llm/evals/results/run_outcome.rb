# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What running a set of experiments produced, and how long it took as a whole.
      RunOutcome = Data.define(:summaries, :seconds)
    end
  end
end
