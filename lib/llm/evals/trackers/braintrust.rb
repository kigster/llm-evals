# frozen_string_literal: true

module LLM
  module Evals
    module Trackers
      # Records each case as a Braintrust eval row in an experiment of the
      # suite's project, through the braintrust gem's own OpenTelemetry
      # exporter, the way `Braintrust::Eval.run` would have, except that the
      # loop stays ours. The gem is required only when this tracker is chosen.
      class Braintrust < Base
        # A set id skips the project lookup in {#start}.
        #
        # @param env [#[]]
        # @return [String, nil] the project BRAINTRUST_PROJECT_ID names
        def self.project_id(env = ENV) = env["BRAINTRUST_PROJECT_ID"].to_s[/\S+/]

        # Overrides {Base.env_key}.
        #
        # @return [String] "BRAINTRUST_API_KEY"
        def self.env_key = "BRAINTRUST_API_KEY"
        # Overrides {Base.gems}.
        #
        # @return [Array<String>] just the braintrust gem
        def self.gems = ["braintrust"]

        attr_reader :experiment_id, :permalink

        # @!attribute [r] experiment_id
        #   @return [String, nil] the Braintrust experiment; nil until {#start}

        # @!attribute [r] permalink
        #   @return [String, nil] the experiment's page; nil until {#start}

        # Overrides {Base#describe}.
        #
        # @return [String] the destination project, by id when there is one
        def describe = "braintrust: project #{context[:project_id] || context[:project].inspect}"

        # Logs in, finds or creates the project, creates the experiment.
        #
        # @param experiment [Actions::Experiment]
        # @return [void]
        def start(experiment)
          ::Braintrust.init(blocking_login: true, auto_instrument: false)
          @state = ::Braintrust.current_state
          @state.login
          project_id = context[:project_id] || ::Braintrust::API::Internal::Projects.new(@state).create(name: context[:project]).fetch("id")
          @experiment_id = ::Braintrust::API::Internal::Experiments.new(@state).create(
            name:       experiment.name,
            project_id: project_id,
            ensure_new: true,
            tags:       [context[:suite], experiment.model.id, "dataset-#{experiment.dataset}"].compact,
            metadata:   metadata(experiment)
          ).fetch("id")
          @permalink = @state.object_permalink(object_type: "experiment", object_id: experiment_id)
          # Braintrust.init installs its exporter on the global provider, which
          # is where the gem's own runner takes its tracer from too.
          @tracer = OpenTelemetry.tracer_provider.tracer("llm-evals")
        end

        # One root "eval" span per case, with the shape Braintrust's own
        # runner emits: input, expected, output, scores and metadata as JSON
        # attributes, parented to the experiment.
        #
        # @param result [Results::RunResult]
        # @return [void]
        def record(result)
          span = @tracer.start_root_span("eval")
          span.set_attribute("braintrust.parent", "experiment_id:#{experiment_id}")
          json(span, "braintrust.span_attributes", { type: "eval", name: result.experiment.name })
          json(span, "braintrust.input_json", { case: result.case.key, text: result.case.input })
          json(span, "braintrust.expected_json", result.case.expected) unless result.case.expected.nil?
          json(span, "braintrust.metadata", case_metadata(result))
          span.set_attribute("braintrust.tags", ["variant-#{result.case.variant}", "dataset-#{result.case.dataset}"])
          if result.failed?
            span.status = OpenTelemetry::Trace::Status.error(result.error)
          else
            json(span, "braintrust.output_json", result.reply.error? ? { "_error" => result.reply.error } : result.reply.output)
            json(span, "braintrust.scores", result.score.metrics.compact)
          end
        ensure
          span&.finish
        end

        # Flushes the spans and hands back the experiment's page.
        #
        # @param _experiment [Actions::Experiment] unused
        # @param _summary [Actions::Experiment::Summary] unused
        # @return [Hash] `url:` the experiment permalink
        def finish(_experiment, _summary)
          provider = OpenTelemetry.tracer_provider
          provider.force_flush if provider.respond_to?(:force_flush)
          { url: permalink }
        end

        private

        # Sets one span attribute as JSON, the form Braintrust reads.
        #
        # @param span [OpenTelemetry::Trace::Span] the span to annotate
        # @param key [String] the attribute name
        # @param value [Object] any JSON-encodable value
        # @return [void]
        def json(span, key, value) = span.set_attribute(key, JSON.dump(value))

        # What the experiment was run with, as Braintrust stores it.
        #
        # @param experiment [Actions::Experiment] the experiment starting
        # @return [Hash{Symbol => Object}]
        def metadata(experiment)
          { model: experiment.model.id, provider: experiment.model.provider.name, dataset: experiment.dataset,
            **experiment.model.settings, **experiment.adapter.metadata }
        end

        # What a case span carries beyond its scores; a failed case has no score or reply to report.
        #
        # @param result [Results::RunResult] the finished case
        # @return [Hash{Symbol => Object}]
        def case_metadata(result)
          base = { case: result.case.key, dataset: result.case.dataset, variant: result.case.variant, difficulty: result.case.difficulty }
          return base.merge(error: result.error) if result.failed?

          base.merge(diagnostics: result.score.diagnostics, outcomes: result.score.outcomes, usage: result.reply.usage.to_h)
        end
      end
    end
  end
end
