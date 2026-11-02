# frozen_string_literal: true

module LLM
  module Evals
    module Trackers
      # Where a run's results go besides the terminal. The gem always owns the
      # run loop; a tracker only receives callbacks: {#start} once per
      # experiment, {#record} once per finished case, {#finish} once with the
      # summary. The local JSON log ({Trackers::Local}) always runs; at most
      # one remote tracker runs beside it, chosen by `--tracker`, the
      # `tracker:` key, or the environment (see {Trackers::Registry#choose}).
      #
      # A tracker for another framework (W&B Weave, an OTLP backend) subclasses
      # this in a consumer or a plugin gem and is registered with `c.tracker`.
      #
      # @abstract Override the three callbacks; declare {.env_key} and {.gems}.
      class Base
        class << self
          # The class name is the default, so a subclass needs no declaration.
          #
          # @return [String] the name `--tracker` and `tracker:` use; the class name, dasherized, by default
          def tracker_name = (name || "Tracker").split("::").last.gsub(/([a-z\d])([A-Z])/, '\1-\2').downcase

          # Nil means the environment can never select this tracker by itself.
          #
          # @return [String, nil] the environment variable whose presence selects this tracker when nothing else does
          def env_key = nil

          # Loaded by {.requirements!} rather than at require time.
          #
          # @return [Array<String>] the optional gems this tracker requires when chosen
          def gems = []

          # A blank value counts as absent.
          #
          # @param env [#[]] the environment, ENV by default
          # @return [Boolean] whether the environment names this tracker
          def detect?(env = ENV) = !env_key.nil? && !env[env_key].to_s.strip.empty?

          # Loads the gems and checks the key, with an error that names both, so
          # a chosen tracker that cannot run says so before any model is called.
          #
          # @param env [#[]] the environment, ENV by default
          # @return [void]
          # @raise [MissingDependency] when a gem is absent
          # @raise [Error] when the key is not set
          def requirements!(env = ENV)
            gems.each do |gem_name|
              LLM::Evals.optional!(gem_name.tr("-", "/"), gem_name, needed_for: "the #{tracker_name} tracker")
            end
            return if env_key.nil? || detect?(env)

            raise Error, "the #{tracker_name} tracker needs #{env_key} in the environment (gems: #{gems.join(", ")})"
          end
        end

        # What {#initialize} was given, for subclasses to read.
        #
        # @return [Hash{Symbol => Object}]
        attr_reader :context

        # Keeps the context whole, so a subclass reads only what it wants.
        #
        # @param context [Hash] `suite:`, `project:`, `project_id:` and `options:` (the tracker's own key in the config file)
        def initialize(**context)
          @context = context
        end

        # Delegates to {.tracker_name}, so an instance and its class agree.
        #
        # @return [String]
        def name = self.class.tracker_name

        # Nothing in this class turns itself off; a subclass may.
        #
        # @return [Boolean] false turns every callback into a no-op
        def enabled? = true

        # Overridden by each tracker to name its destination.
        #
        # @return [String] one line for `--verbose`: where this tracker sends things, and why
        def describe = name

        # Called once per experiment, before any case runs.
        #
        # @param _experiment [Actions::Experiment] the experiment starting
        # @return [void]
        def start(_experiment) = nil

        # Called once per finished case, one at a time under the experiment's lock.
        #
        # @param _result [Results::RunResult] the finished case
        # @return [void]
        def record(_result) = nil

        # Called once per experiment, after the last case.
        #
        # @param _experiment [Actions::Experiment] the experiment finishing
        # @param _summary [Actions::Experiment::Summary] its totals
        # @return [Hash] `url:` to the experiment when one is known, else nil
        def finish(_experiment, _summary) = { url: nil }

        # Empty when the config file has no section for this tracker.
        #
        # @return [Hash] the tracker's own section of the config file
        def options = context.fetch(:options, nil) || {}
      end
    end
  end
end
