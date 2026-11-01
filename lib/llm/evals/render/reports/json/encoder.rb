# frozen_string_literal: true

require "time"

module LLM
  module Evals
    module Render
      module Reports
        class JSON
          # Completed runs into the snapshot's document. {Decoder} reads it back.
          class Encoder
            # @param summaries [Array<Experiment::Summary>]
            # @param metrics [Array<Metric>]
            # @param weighted_score [WeightedScore, nil]
            # @param run_options [Hash]
            # @param suite [String]
            def initialize(summaries, metrics:, weighted_score:, run_options:, suite:)
              @summaries = summaries
              @metrics = metrics
              @weighted_score = weighted_score
              @run_options = run_options
              @suite = suite
            end

            # @return [String]
            def call
              ::JSON.pretty_generate(
                format:       FORMAT,
                version:      VERSION,
                suite:        @suite,
                generated_at: Time.now.iso8601,
                run_options:  plain(@run_options),
                metrics:      @metrics.map { { name: it.name, description: it.description, aggregate: it.aggregate, primary: it.primary } },
                weights:      @weighted_score&.weights,
                call_stats:   CallStats.for_run(@summaries, @run_options).rows.map(&:to_h),
                summaries:    @summaries.map { summary(it) }
              )
            end

            private

            def plain(value)
              case value
              when Hash then value.to_h { |key, item| [key.to_s, plain(item)] }
              when Array then value.map { plain(it) }
              when Symbol then value.to_s
              else value
              end
            end

            def summary(summary)
              {
                model:     { id: summary.model.id, provider: summary.model.provider.name, settings: summary.model.settings },
                dataset:   summary.dataset,
                name:      summary.name,
                means:     summary.means,
                errors:    summary.errors,
                duration:  summary.duration,
                permalink: summary.permalink,
                usage:     summary.usage.to_h,
                results:   summary.results.map { result(it) }
              }
            end

            def result(result)
              { case: kase(result.case), reply: reply(result.reply), score: score(result.score), duration: result.duration, error: result.error }
            end

            def kase(kase)
              { id: kase.id, dataset: kase.dataset, variant: kase.variant, input: kase.input, expected: kase.expected, metadata: kase.metadata }
            end

            def reply(reply)
              reply && { output: reply.output, raw: reply.raw, usage: reply.usage.to_h, error: reply.error, metadata: reply.metadata }
            end

            def score(score)
              score && { value: score.value, metrics: score.metrics, outcomes: score.outcomes, diagnostics: score.diagnostics }
            end
          end
        end
      end
    end
  end
end
