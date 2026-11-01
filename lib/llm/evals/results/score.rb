# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What a {Scoring::Scorer} says about one reply. `value` is the case's overall
      # score in 0..1; `metrics` holds one entry per {Scoring::Metric} the scorer
      # declares, nil where the case does not apply; `outcomes` and
      # `diagnostics` are free-form, keyed by field, and only ever displayed.
      #
      # @!attribute [r] value
      #   @return [Float] the overall score, in 0..1
      # @!attribute [r] metrics
      #   @return [Hash{String => Float, nil}] by metric name
      # @!attribute [r] outcomes
      #   @return [Hash] free-form, keyed by field; only displayed
      # @!attribute [r] diagnostics
      #   @return [Hash] free-form, keyed by field; only displayed
      Score = Data.define(:value, :metrics, :outcomes, :diagnostics) do
        # Refuses a value outside 0..1, and turns metric names into Strings so that
        # a fresh score and one read back from JSON look up the same way.
        #
        # @param value [Numeric] the overall score, in 0..1
        # @param metrics [Hash{String, Symbol => Float, nil}] by metric name
        # @param outcomes [Hash] free-form, keyed by field
        # @param diagnostics [Hash] free-form, keyed by field
        # @raise [ArgumentError] when the value is not a number within 0..1
        def initialize(value:, metrics: {}, outcomes: {}, diagnostics: {})
          raise ArgumentError, "score value #{value.inspect} is not within 0..1" unless value.is_a?(Numeric) && (0..1).cover?(value)

          super(value: value.to_f, metrics: metrics.transform_keys(&:to_s), outcomes: outcomes, diagnostics: diagnostics)
        end

        # The score of a reply the model failed: 0 everywhere, the failure as a diagnostic.
        #
        # @param metrics [Array<Scoring::Metric>]
        # @param error [String]
        # @return [Score]
        def self.failed(metrics, error)
          new(value: 0.0, metrics: metrics.to_h { [it.name, 0.0] }, diagnostics: { "error" => error })
        end
      end
    end
  end
end
