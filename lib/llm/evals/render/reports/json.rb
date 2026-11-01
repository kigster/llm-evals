# frozen_string_literal: true

require "json"

module LLM
  module Evals
    module Render
      module Reports
        # A portable snapshot of completed runs, suitable for rendering later
        # without repeating model calls or depending on the original case files.
        class JSON
          FORMAT = "llm-evals-report"
          VERSION = 1
          Loaded = Data.define(:suite, :generated_at, :run_options, :summaries, :metrics, :weighted_score)
          SavedExperiment = Data.define(:model)

          # @param summaries [Array<Experiment::Summary>]
          # @param metrics [Array<Metric>]
          # @param weighted_score [WeightedScore, nil]
          # @param run_options [Hash]
          # @return [String]
          def self.dump(summaries, metrics:, weighted_score: nil, run_options: {})
            Encoder.new(summaries, metrics:, weighted_score:, run_options:, suite: LLM::Evals.configuration.name).call
          end

          # @param source [String] report JSON, not a path
          # @param providers [Providers::Registry]
          # @return [Loaded]
          # @raise [Error] for an unknown format/version or provider
          def self.decode(source, providers:) = Decoder.new(providers:).call(source)

          def self.load(source, providers:) = decode(source, providers:)
        end
      end
    end
  end
end
