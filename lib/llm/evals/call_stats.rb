# frozen_string_literal: true

module LLM
  module Evals
    # How many calls a run made and how fast they came back, per provider, per
    # vendor behind it, and per model at every setting. Latency counts only
    # calls that worked, since a refusal returns quickly and would flatter the
    # slowest model. Requests per second are over the whole run, so the rows
    # compare with each other.
    class CallStats
      P95 = 0.95

      Row = Data.define(:scope, :name, :requests, :errors, :per_second, :latency, :p95)

      # @param summaries [Array<Experiment::Summary>]
      # @param run_options [Hash] as a run recorded them, with symbol keys or, read back from JSON, string keys
      # @return [CallStats]
      def self.for_run(summaries, run_options)
        new(summaries, seconds: run_options.dig(:effective, :seconds) || run_options.dig("effective", "seconds"))
      end

      # @param summaries [Array<Experiment::Summary>]
      # @param seconds [Numeric, nil] how long the run took; nil leaves requests per second empty
      def initialize(summaries, seconds:)
        @summaries = summaries
        @seconds = seconds
      end

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

      def vendor(summary) = summary.model.id.split("/").first

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
