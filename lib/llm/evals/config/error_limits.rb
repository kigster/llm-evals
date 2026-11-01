# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # The `errors:` section: when to give up on a run. Both limits must be met,
      # and `percent` needs `total`, since one failed first call is already 100%.
      #
      # @!attribute [r] total
      #   @return [Integer] errors before the run may abort
      # @!attribute [r] percent
      #   @return [Numeric, nil] the share of finished calls that must have failed
      ErrorLimits = Data.define(:total, :percent) do
        # Checks the section as the file wrote it.
        #
        # @param section [Object] the section as the file has it, not nil
        # @param path [String] names the file in an error
        # @return [ErrorLimits]
        # @raise [Error] on a limit that is missing or out of range
        def self.from_hash(section, path:)
          limits = section["abort_after"] if section.is_a?(Hash)
          raise Error, "#{path}: errors needs an abort_after: mapping of total and percent" unless limits.is_a?(Hash)

          total = limits["total"]
          percent = limits["percent"]
          raise Error, "#{path}: errors.abort_after.total must be a whole number above 0" unless total.is_a?(Integer) && total.positive?
          unless percent.nil? || (percent.is_a?(Numeric) && percent.positive? && percent <= 100)
            raise Error, "#{path}: errors.abort_after.percent must be above 0 and at most 100"
          end

          new(total:, percent:)
        end

        # A new one each time, since a budget counts one run's calls.
        #
        # @return [Actions::ErrorBudget]
        def budget = Actions::ErrorBudget.new(total:, percent:)
      end
    end
  end
end
