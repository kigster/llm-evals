# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class JSON
          # A snapshot's document back into runs, one mapper for each of {Encoder}'s.
          class Decoder
            # @param providers [Providers::Registry]
            def initialize(providers:)
              @providers = providers
            end

            # @param source [String] report JSON, not a path
            # @return [Loaded]
            # @raise [Error] for an unknown format/version or provider
            def call(source)
              document = ::JSON.parse(source)
              unless document["format"] == FORMAT && document["version"] == VERSION
                raise Error, "unsupported report format version (expected #{FORMAT} v#{VERSION})"
              end

              metrics = document.fetch("metrics").map { metric(it) }
              Loaded.new(suite: document.fetch("suite", "llm-evals"),
                generated_at: document["generated_at"],
                run_options: document.fetch("run_options", {}),
                summaries: document.fetch("summaries").map { summary(it) },
                metrics:,
                weighted_score: weighted_score(document["weights"], metrics))
            rescue ::JSON::ParserError => e
              raise Error, "invalid report JSON: #{e.message}"
            end

            private

            def metric(data)
              Scoring::Metric.new(name: data.fetch("name"),
                description: data.fetch("description", ""),
                aggregate: data.fetch("aggregate", "mean").to_sym,
                primary: data.fetch("primary", false))
            end

            def weighted_score(weights, metrics)
              Scoring::WeightedScore.new(weights, metrics: metrics.map(&:name)) if weights && !weights.empty?
            end

            def summary(data)
              model = model(data.fetch("model"))
              experiment = SavedExperiment.new(model:)
              Actions::Experiment::Summary.new(model:,
                dataset: data.fetch("dataset"),
                name: data.fetch("name"),
                means: data.fetch("means"),
                results: data.fetch("results").map { result(it, experiment) },
                errors: data.fetch("errors", []),
                duration: data.fetch("duration", 0.0),
                permalink: data["permalink"],
                usage: Stats::Usage.from(data["usage"]))
            end

            def model(data)
              provider = @providers.find { it.name == data.fetch("provider") }
              raise Error, "report uses unknown provider #{data.fetch("provider").inspect}" unless provider

              Models::Model.new(id: data.fetch("id"), provider:, settings: data.fetch("settings", {}))
            end

            def result(data, experiment)
              Results::RunResult.new(experiment:,
                case: kase(data.fetch("case")),
                reply: reply(data["reply"]),
                score: score(data["score"]),
                duration: data.fetch("duration", 0.0),
                error: data["error"])
            end

            def kase(data)
              Datasets::Case.new(id: data.fetch("id"),
                dataset: data.fetch("dataset"),
                variant: data.fetch("variant"),
                input: data.fetch("input"),
                expected: data["expected"],
                path: "",
                metadata: (data["metadata"] || {}).transform_keys(&:to_sym))
            end

            def reply(data)
              return unless data

              Results::Reply.new(output: data["output"], raw: data["raw"], usage: data["usage"], error: data["error"], metadata: data["metadata"] || {})
            end

            def score(data)
              return unless data

              Results::Score.new(value: data.fetch("value"),
                metrics: data["metrics"] || {},
                outcomes: data["outcomes"] || {},
                diagnostics: data["diagnostics"] || {})
            end
          end
        end
      end
    end
  end
end
