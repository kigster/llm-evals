# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # How the page measures a contender and ranks a group of them. Standings
          # and dataset sections differ in what they group, never in this.
          class Ranking
            # @param result [Results::RunResult]
            # @return [Boolean] whether the result counts for nothing
            def self.failed?(result) = !result.score || result.failed? || result.reply&.error?

            # @param metrics [Array<Scoring::Metric>]
            # @param weighted_score [Scoring::WeightedScore, nil]
            def initialize(metrics:, weighted_score:)
              @metrics = metrics
              @weighted_score = weighted_score
            end

            # @return [String]
            def primary_metric = @metrics.find(&:primary)&.name || "score"

            # @param group [Array<Actions::Experiment::Summary>]
            # @param expected_keys [Array<String>]
            # @return [Hash{Symbol => Object}] model coverage and score inputs
            def entry(group, expected_keys)
              results = group.flat_map(&:results).uniq { it.case.key }
              failures = results.count { self.class.failed?(it) }
              successful_keys = results.reject { self.class.failed?(it) }.map { it.case.key }.uniq
              {
                model:         group.first.model,
                successful:    successful_keys.length,
                total:         expected_keys.length,
                errors:        failures,
                cost:          group.sum { it.usage.cost_usd },
                input_tokens:  group.sum { it.usage.input_tokens },
                output_tokens: group.sum { it.usage.output_tokens },
                row:           row(group, results, failures),
                complete:      expected_keys.length.positive? && successful_keys.sort == expected_keys.uniq.sort && failures.zero?
              }
            end

            # Records each entry's :ranking, compared within the entries given.
            #
            # @param entries [Array<Hash{Symbol => Object}>]
            # @return [void]
            def rank(entries)
              rows = entries.map { it[:row] }
              scores = @weighted_score ? @weighted_score.call(rows) : rows.map { it[primary_metric] }
              entries.zip(scores).each { |entry, score| entry[:ranking] = score }
            end

            private

            def row(group, results, failures)
              metric_means = @metrics.to_h { |metric| [metric.name, mean(results.filter_map { it.score&.metrics&.fetch(metric.name, nil) })] }
              scores = results.filter_map { it.score&.value unless it.failed? || it.reply&.error? }
              metric_means.merge("score" => mean(scores), "errors" => failures, "time" => group.sum(&:duration), "cost" => group.sum { it.usage.cost_usd })
            end

            def mean(values) = values.empty? ? nil : values.sum.fdiv(values.size)
          end
        end
      end
    end
  end
end
