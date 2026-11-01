# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # How the lineup's weights divide the weighted score, without calling
      # anything: a weight is relative, so its share is what it really counts for.
      class Weights < Command
        desc "Print how the config file's weights divide the weighted score"

        example [
          "                                  # the suite's .llm-evals.config.yml",
          "-C evals/.llm-evals.config.yml    # another lineup file"
        ]

        option :config, aliases: ["-C"], desc: "The lineup file (default: the suite's .llm-evals.config.yml)"

        def call(config: nil, **)
          lineup = config ? Config.new(File.expand_path(config)) : configuration.lineup
          weights = lineup.score_weights
          raise Error, "#{lineup.path}: no weighted_score.weights to show" if weights.empty?

          weighted = WeightedScore.new(weights, metrics: configuration.scorer.metrics.map(&:name))
          rows = weighted.shares.map { |name, share| [direction(name, weighted.weights[name]), weighted.weights[name], format("%.1f%%", share * 100)] }
          table(rows, header: %w[Column Weight Share], fill: 0)
        end

        private

        # @return [String] the column, marked with the direction that is good for it
        def direction(name, weight)
          weight.negative? ? pastel.bold.blue("↓ #{name}") : pastel.bold.yellow("↑ #{name}")
        end
      end
    end
  end
end
