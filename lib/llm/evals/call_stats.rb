# frozen_string_literal: true

module LLM
  module Evals
    # How many calls a run made and how fast they came back, per provider, per
    # vendor behind it, and per model at every setting. Latency counts only
    # calls that worked, since a refusal returns quickly and would flatter the
    # slowest model. Requests per second are over the whole run, so the rows
    # compare with each other.
    class CallStats
      Row = Data.define(:scope, :name, :requests, :errors, :per_second, :latency, :p95)

      # Nearest-rank, so the value is one a call really took.
      #
      # @param values [Array<Numeric>]
      # @param share [Float] from 0 to 1
      # @return [Numeric, nil] nil with no values
      def self.percentile(values, share)
        return if values.empty?

        values.sort[[(share * values.size).ceil - 1, 0].max]
      end

      # @param values [Array<Numeric>]
      # @return [Float, nil] nil with no values
      def self.mean(values) = values.empty? ? nil : values.sum.fdiv(values.size)

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
            models = by_vendor.group_by { it.model.id }.map { |id, group| row(:model, "#{provider.name}/#{id}", group) }
            provider.direct? ? models : [row(:vendor, "#{provider.name}/#{name}", by_vendor), *models]
          end
        end
      end

      private

      def vendor(summary) = summary.model.id.split("/").first

      def row(scope, name, summaries)
        results = summaries.flat_map(&:results)
        worked = results.reject(&:errored?).map(&:duration)
        Row.new(scope:,
          name:,
          requests:   results.size,
          errors:     results.count(&:errored?),
          per_second: @seconds&.positive? ? results.size.fdiv(@seconds) : nil,
          latency:    self.class.mean(worked),
          p95:        self.class.percentile(worked, 0.95))
      end
    end
  end
end
