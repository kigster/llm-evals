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

        # Prints each weighted column's share, and in red the metrics no weight covers.
        #
        # @param config [String, nil] the lineup file; nil for the suite's
        # @return [void]
        # @raise [Error] when the file sets no weights
        def call(config: nil, **)
          lineup = config ? Config.new(File.expand_path(config)) : configuration.lineup
          weights = lineup.score_weights
          raise Error, "#{lineup.path}: no weighted_score.weights to show" if weights.empty?

          metrics = configuration.scorer.metrics.map(&:name)
          weighted = Scoring::WeightedScore.new(weights, metrics:)
          rows = weighted.shares.map { |name, share| [direction(name, weighted.weights[name]), weighted.weights[name], format("%.1f%%", share * 100)] }
          unweighted = (metrics - weighted.weights.keys).map { [pastel.red(it), "", ""] }
          table(rows + unweighted, header: %w[Column Weight Share], fill: 0)
        end

        private

        # A negative weight means less is better.
        #
        # @param name [String]
        # @param weight [Numeric]
        # @return [String] the column, marked with the direction that is good for it
        def direction(name, weight)
          weight.negative? ? pastel.bold.blue("↓ #{name}") : pastel.bold.yellow("↑ #{name}")
        end
      end
    end
  end
end
