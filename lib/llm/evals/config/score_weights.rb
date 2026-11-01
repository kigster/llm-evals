# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # The `weighted_score:` section; see {Scoring::WeightedScore}.
      module ScoreWeights
        # Only checks the shape; {Scoring::WeightedScore} judges the columns and numbers.
        #
        # @param section [Object, nil] the section as the file has it
        # @param path [String] names the file in an error
        # @return [Hash{String => Object}] by column; empty when the file sets none
        # @raise [Error] when either level is not a mapping
        def self.from_hash(section, path:)
          return {} if section.nil?

          weights = section["weights"] if section.is_a?(Hash)
          raise Error, "#{path}: weighted_score needs a weights: mapping of column to number" unless weights.is_a?(Hash)

          weights.transform_keys(&:to_s)
        end
      end
    end
  end
end
