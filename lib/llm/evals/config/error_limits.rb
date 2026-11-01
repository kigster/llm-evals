# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # The `errors:` section: when to give up on a run. Both limits must be met,
      # and `percent` needs `total`, since one failed first call is already 100%.
      ErrorLimits = Data.define(:total, :percent) do
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
        # @return [ErrorBudget]
        def budget = ErrorBudget.new(total:, percent:)
      end
    end
  end
end
