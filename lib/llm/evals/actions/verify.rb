# frozen_string_literal: true

module LLM
  module Evals
    module Actions
      # Offline consistency checks over every case, so a typo in the suite is
      # caught before it is billed as a model's mistake. The gem checks what
      # every suite has: an input and a parsable expected answer. The adapter
      # checks each dataset's shared files, and the scorer each case against
      # what it will demand of it.
      class Verify
        # @param configuration [Runtime::Configuration] the suite to check
        def initialize(configuration = LLM::Evals.configuration)
          @configuration = configuration
        end

        # Asks the adapter about each dataset, then checks every case in it.
        #
        # @return [Hash{String => Array<String>}] problems by "dataset/id"; empty when all is sound
        def problems
          discovery = @configuration.discovery
          failures = {}
          discovery.datasets.each do |dataset|
            Array(adapter.verify(dataset)).each { (failures[dataset.to_s] ||= []) << it }
            discovery.cases(dataset: dataset).each do |kase|
              list = case_problems(kase)
              failures[kase.key] = list unless list.empty?
            end
          end
          failures
        end

        # Checks one case; an exception from the scorer or adapter is reported as a problem.
        #
        # @param kase [Datasets::Case] the case to check
        # @return [Array<String>] problems; empty when the case is sound
        def case_problems(kase)
          problems = []
          problems << "input is empty" if kase.input.empty?
          problems << kase.metadata[:expected_error] if kase.metadata[:expected_error]
          return problems unless kase.expected?

          problems.concat(Array(scorer.verify(kase, context: adapter.context(kase))))
        rescue StandardError => e
          problems << "#{e.class}: #{e.message}"
        end

        private

        # The suite's adapter.
        #
        # @return [Actions::Adapter, nil] nil when the suite has not registered one
        def adapter = @configuration.adapter
        # The suite's scorer.
        #
        # @return [Scoring::Scorer, nil] nil when the suite has not registered one
        def scorer = @configuration.scorer
      end
    end
  end
end
