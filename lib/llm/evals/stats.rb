# frozen_string_literal: true

module LLM
  module Evals
    # The arithmetic reports and summaries share.
    module Stats
      module_function

      # Nearest-rank, so the value is one a call really took.
      #
      # @param values [Array<Numeric>]
      # @param share [Float] from 0 to 1
      # @return [Numeric, nil] nil with no values
      def percentile(values, share)
        return if values.empty?

        values.sort[[(share * values.size).ceil - 1, 0].max]
      end

      # @param values [Array<Numeric>]
      # @return [Float, nil] nil with no values
      def mean(values) = values.empty? ? nil : values.sum.fdiv(values.size)
    end
  end
end
