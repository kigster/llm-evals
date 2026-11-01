# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What running a set of experiments produced, and how long it took as a whole.
      #
      # @!attribute [r] summaries
      #   @return [Array<Actions::Experiment::Summary>] the experiments that finished
      # @!attribute [r] seconds
      #   @return [Float] wall-clock time for the whole run, which experiments overlap within
      RunOutcome = Data.define(:summaries, :seconds)
    end
  end
end
