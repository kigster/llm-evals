# frozen_string_literal: true

require "json"

module LLM
  module Evals
    module Render
      module Reports
        # A portable snapshot of completed runs, suitable for rendering later
        # without repeating model calls or depending on the original case files.
        class JSON
          # Identifies a document as one of these snapshots, so other JSON is refused.
          FORMAT = "llm-evals-report"
          # The document's schema version; {Decoder} refuses any other.
          VERSION = 1
          # A snapshot read back: what {HTML} and the terminal display are given.
          #
          # @!attribute [r] suite
          #   @return [String] the suite's name
          # @!attribute [r] generated_at
          #   @return [String, nil] when the snapshot was written, ISO 8601
          # @!attribute [r] run_options
          #   @return [Hash{String => Object}] as the run recorded them, with string keys now
          # @!attribute [r] summaries
          #   @return [Array<Actions::Experiment::Summary>]
          # @!attribute [r] metrics
          #   @return [Array<Scoring::Metric>]
          # @!attribute [r] weighted_score
          #   @return [Scoring::WeightedScore, nil] nil when the lineup set no weights
          Loaded = Data.define(:suite, :generated_at, :run_options, :summaries, :metrics, :weighted_score)
          # Stands in for the {Actions::Experiment} on a result read back; a snapshot keeps only its model.
          #
          # @!attribute [r] model
          #   @return [Models::Model]
          SavedExperiment = Data.define(:model)

          # Serializes completed runs under the configured suite's name.
          #
          # @param summaries [Array<Actions::Experiment::Summary>]
          # @param metrics [Array<Scoring::Metric>]
          # @param weighted_score [Scoring::WeightedScore, nil]
          # @param run_options [Hash]
          # @return [String]
          def self.dump(summaries, metrics:, weighted_score: nil, run_options: {})
            Encoder.new(summaries, metrics:, weighted_score:, run_options:, suite: LLM::Evals.configuration.name).call
          end

          # Parses a snapshot back into runs. Providers are looked up by name, so
          # the document's providers must still be configured.
          #
          # @param source [String] report JSON, not a path
          # @param providers [Providers::Registry]
          # @return [Loaded]
          # @raise [KeyError] when a required field is missing
          # @raise [Error] for an unknown format/version or provider
          def self.decode(source, providers:) = Decoder.new(providers:).call(source)

          # Alias of {.decode}.
          #
          # @param source [String] report JSON, not a path
          # @param providers [Providers::Registry]
          # @return [Loaded]
          # @raise [Error] for an unknown format/version or provider
          def self.load(source, providers:) = decode(source, providers:)
        end
      end
    end
  end
end
