# frozen_string_literal: true

module LLM
  module Evals
    module Stats
      # How many calls a run made and how fast they came back, per provider, per
      # vendor behind it, and per model at every setting. Latency counts only
      # calls that worked, since a refusal returns quickly and would flatter the
      # slowest model. Requests per second are over the whole run, so the rows
      # compare with each other.
      class CallStats
        # The share {Stats.percentile} is asked for, shared with {Actions::Experiment::Summary#latency_p95}.
        P95 = 0.95

        # One line of the report: a provider, a vendor behind it, or one model at one setting.
        #
        # @!attribute [r] scope
        #   @return [Symbol] :provider, :vendor or :model
        # @!attribute [r] name
        #   @return [String] the provider's name, or "provider/vendor" or "provider/model"
        # @!attribute [r] requests
        #   @return [Integer] every call made, including failures
        # @!attribute [r] errors
        #   @return [Integer] calls that raised or that the model failed
        # @!attribute [r] per_second
        #   @return [Float, nil] over the whole run; nil when its length is unknown or zero
        # @!attribute [r] latency
        #   @return [Float, nil] mean seconds of the calls that worked; nil with none
        # @!attribute [r] p95
        #   @return [Float, nil] 95th percentile seconds of the calls that worked; nil with none
        Row = Data.define(:scope, :name, :requests, :errors, :per_second, :latency, :p95)

        # Reads the run's length out of its recorded options, however they were stored.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param run_options [Hash] as a run recorded them, with symbol keys or, read back from JSON, string keys
        # @return [CallStats]
        def self.for_run(summaries, run_options)
          new(summaries, seconds: run_options.dig(:effective, :seconds) || run_options.dig("effective", "seconds"))
        end

        # Computes nothing until {#rows}.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param seconds [Numeric, nil] how long the run took; nil leaves requests per second empty
        def initialize(summaries, seconds:)
          @summaries = summaries
          @seconds = seconds
        end

        # A direct provider has no vendor rows, since it serves only its own models.
        #
        # @return [Array<Row>] each provider, then its vendors, each followed by its models
        def rows
          @summaries.group_by { it.model.provider }.flat_map do |provider, by_provider|
            [row(:provider, provider.name, by_provider)] + by_provider.group_by { vendor(it) }.flat_map do |name, by_vendor|
              models = by_vendor.group_by { it.model.to_s }.map { |model, group| row(:model, "#{provider.name}/#{model}", group) }
              provider.direct? ? models : [row(:vendor, "#{provider.name}/#{name}", by_vendor), *models]
            end
          end
        end

        private

        # The vendor is the id's first segment, "anthropic" in "anthropic/claude-haiku-5.5".
        #
        # @param summary [Actions::Experiment::Summary]
        # @return [String]
        def vendor(summary) = summary.model.id.split("/").first

        # Totals one group of summaries into a row.
        #
        # @param scope [Symbol] :provider, :vendor or :model
        # @param name [String] the row's label
        # @param summaries [Array<Actions::Experiment::Summary>] the group
        # @return [Row]
        def row(scope, name, summaries)
          results = summaries.flat_map(&:results)
          worked = summaries.flat_map(&:worked_durations)
          Row.new(scope:,
            name:,
            requests:   results.size,
            errors:     results.count(&:errored?),
            per_second: @seconds&.positive? ? results.size.fdiv(@seconds) : nil,
            latency:    Stats.mean(worked),
            p95:        Stats.percentile(worked, P95))
        end
      end
    end
  end
end
