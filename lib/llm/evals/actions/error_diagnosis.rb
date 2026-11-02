# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # What a streak of failed calls has in common: the messages, and how much of
      # the run they touch. One failing model and a failing key call for different
      # answers, so this names which it is.
      #
      # @!attribute [r] failures
      #   @return [Array<Results::RunResult>] the failed calls
      # @!attribute [r] runs
      #   @return [Array<Experiment>] the whole run, which "all" is measured against
      ErrorDiagnosis = Data.define(:failures, :runs) do
        # The distinct messages, most frequent first.
        #
        # @return [Array<Array(String, Integer)>] each message with its count
        def messages
          failures.map { it.error || it.reply.error }.map(&:to_s).tally.sort_by { |message, count| [-count, message] }
        end

        # @return [Scope] the models that failed
        def models = scope(failures.map { it.experiment.model.id }, runs.map { it.model.id })

        # @return [Scope] the datasets that failed
        def datasets = scope(failures.map { it.case.dataset }, runs.map(&:dataset))

        # @return [Scope] the cases that failed
        def cases = scope(failures.map { it.case.key }, runs.flat_map(&:cases).map(&:key))

        private

        # @param failed [Array<String>] one name per failure
        # @param planned [Array<String>] one name per planned item
        # @return [Scope]
        def scope(failed, planned) = ErrorDiagnosis::Scope.new(failed: failed.uniq.sort, total: planned.uniq.size)
      end

      # How much of one dimension of the run has failed.
      #
      # @!attribute [r] failed
      #   @return [Array<String>] the names that failed, sorted
      # @!attribute [r] total
      #   @return [Integer] how many the run planned
      ErrorDiagnosis::Scope = Data.define(:failed, :total) do
        # @return [Boolean] whether every planned one failed
        def all? = failed.size >= total
      end
    end
  end
end
