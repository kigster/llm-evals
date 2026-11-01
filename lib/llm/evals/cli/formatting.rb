# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # How a command prints the numbers every report shares.
      module Formatting
        private

        # A missing number prints as a dash, never as 0%, which would read as a score.
        #
        # @param value [Float, nil] a fraction, where 1.0 is 100%
        # @return [String]
        def percent(value) = value.nil? ? "-" : format("%.1f%%", value * 100)

        # Four decimals, since a single cheap experiment can cost a fraction of a cent.
        #
        # @param value [Numeric]
        # @return [String]
        def dollars(value) = format("$%.4f", value.to_f)
      end
    end
  end
end
