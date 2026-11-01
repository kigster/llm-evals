# frozen_string_literal: true

module LLM
  module Evals
    module Trackers
      # The tracker classes a run may choose from, by name, and the choice
      # itself: exactly one remote tracker, or none. A consumer or a plugin
      # gem registers its own with `c.tracker`.
      class Registry
        include Enumerable

        # Spellings of "no remote tracker" on the command line and in the config.
        NONE = %w[none local off].freeze

        # @return [Registry] Braintrust and Logfire
        def self.default = new([Braintrust, Logfire])

        # The array is copied, so registering later does not touch the caller's.
        #
        # @param classes [Array<Class<Base>>]
        def initialize(classes = [])
          @classes = classes.dup
        end

        # Later registration wins, which is how a suite swaps a built-in tracker.
        #
        # @param klass [Class<Base>] replaces one registered under the same name
        # @return [Class<Base>] the class given
        def register(klass)
          @classes.reject! { it.tracker_name == klass.tracker_name }
          @classes << klass
          klass
        end

        # Walks the classes in registration order.
        #
        # @yieldparam klass [Class<Base>] each tracker class
        # @return [Array<Class<Base>>, Enumerator] the list; an Enumerator without a block
        def each(&) = @classes.each(&)

        # For {#named}'s error message.
        #
        # @return [Array<String>]
        def names = map(&:tracker_name)

        # Finds a tracker class by its {Base.tracker_name}.
        #
        # @param name [String, Symbol] the name as given
        # @return [Class<Base>]
        # @raise [Error] naming the known trackers
        def named(name)
          find { it.tracker_name == name.to_s } || raise(Error, "no tracker named #{name.to_s.inspect}; known: #{names.join(", ")}")
        end

        # The one remote tracker to run, in this precedence: `--tracker`,
        # then the config's `tracker:`, then the environment, where a single
        # tracker's key being set selects it and two or more is an ambiguity
        # to be settled by naming one. `--local` is none.
        #
        # @param flag [String, nil] what `--tracker` was given
        # @param config [String, nil] the config file's `tracker:`
        # @param env [#[]] the environment, ENV by default
        # @param local [Boolean] `--local`
        # @return [Array(Class<Base>, String), nil] the class and why it was chosen; nil for none
        # @raise [Error] on an unknown name or an ambiguous environment
        def choose(flag: nil, config: nil, env: ENV, local: false)
          return nil if local
          return choice(flag, "--tracker") if present?(flag)
          return choice(config, "tracker: in the config file") if present?(config)

          detected = @classes.select { it.detect?(env) }
          case detected.size
          when 0 then nil
          when 1 then [detected.first, "#{detected.first.env_key} is set (pass --tracker or set tracker: to choose explicitly)"]
          else
            raise Error,
              "more than one tracker is configured in the environment (#{detected.map(&:env_key).join(", ")}); " \
              "choose one with --tracker #{detected.map(&:tracker_name).join("|")} or tracker: in the config file"
          end
        end

        private

        # Whether a flag or config value actually says something; blank counts as unset.
        #
        # @param value [String, nil] the value given
        # @return [Boolean]
        def present?(value) = !value.nil? && !value.to_s.strip.empty?

        # Resolves a named choice, where the {NONE} spellings mean no remote tracker.
        #
        # @param name [String] the name as given
        # @param from [String] where it came from, for `--verbose`
        # @return [Array(Class<Base>, String), nil] the class and the reason; nil for none
        # @raise [Error] on an unknown name
        def choice(name, from)
          return nil if NONE.include?(name.to_s)

          [named(name), from]
        end
      end
    end
  end
end
