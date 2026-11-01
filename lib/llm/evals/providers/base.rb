# frozen_string_literal: true

module LLM
  module Evals
    module Providers
      # What answers a {Models::Model}'s calls: one API, the ids it serves, the keys it
      # needs and the models it lists. A suite with its own transport
      # subclasses this and registers it through `c.provider`.
      #
      # @abstract Override {#serves?}, {#env_keys}, {#catalog} and {#complete}.
      class Base
        # The reasoning efforts this provider's API accepts.
        EFFORTS = %w[none minimal low medium high xhigh max].freeze

        # The kind of request this provider answers; see {Config::REQUEST_TYPES}.
        # A suite admits a provider only when its config lists this type.
        #
        # @return [Symbol]
        def request_type
          raise NotImplementedError, "#{self.class}#request_type must be one of #{Config::REQUEST_TYPES.join(", ")}"
        end

        # One line on what the request type is, for the README and `--help`;
        # a suite's config never says it, the provider owns it.
        #
        # @return [String]
        def request_type_description = ""

        # A direct provider serves a vendor's own API and is reached only
        # through its own section of the lineup; it never claims another's id,
        # however the id is spelled.
        #
        # @return [Boolean]
        def direct? = false

        # @return [String] short name, for messages and the leaderboard
        def name = self.class.name.split("::").last.gsub(/([a-z\d])([A-Z])/, '\1-\2').downcase

        # @param model_id [String] as the lineup names it
        # @return [Boolean] whether this provider serves the model
        def serves?(model_id) = model_id.start_with?(prefix)

        # @return [String] the id prefix this provider claims; "" claims everything
        def prefix = ""

        # @param model_id [String]
        # @return [String] the id as the provider's API knows it
        def model_name(model_id) = model_id.delete_prefix(prefix)

        # @return [Array<String>] environment variables a run through this provider needs
        def env_keys = []

        # @return [Array<String>] the efforts the `-e` flag accepts for this provider's models
        def efforts = EFFORTS

        # Lists the model ids the provider serves, from the network, so a
        # misspelled id aborts the run before any experiment starts instead
        # of failing every case and showing up as a row of errors.
        #
        # @return [Array<String>, nil] ids as the lineup names them; nil when the provider cannot list them
        def catalog = nil

        # Prepares the client once per process, after the env files loaded.
        #
        # @option options [String] :app_name what the client tells the API the caller is
        # @return [void]
        def setup!(**) = nil

        # @param model [Models::Model]
        # @param system [String, nil]
        # @param user [String]
        # @param json [Boolean]
        # @return [Results::Completion]
        def complete(model, system:, user:, json: true)
          raise NotImplementedError, "#{self.class}#complete must return an LLM::Evals::Results::Completion"
        end

        # @param model [Models::Model]
        # @param state [Object]
        # @param questions [Hash{String => Hash}]
        # @return [Results::Completion]
        def ask(model, state:, questions:)
          raise NotImplementedError, "#{self.class} does not answer typed questions"
        end

        # @param error [StandardError] what a call raised
        # @return [Boolean] whether the same call may work later
        def retryable?(_error) = false

        # @param error [StandardError] what a call raised
        # @return [Numeric, nil] the seconds the API asked to wait, if it did
        def retry_after(_error) = nil

        # @param contender [Models::Contender]
        # @param throttle [Models::Throttle]
        # @return [Models::Model]
        def model_for(contender, throttle: Models::Throttle.new) = Models::Model.new(id: contender.model, provider: self, settings: contender.settings, throttle:)

        # Every id in `model_ids` the provider does not list.
        #
        # @param model_ids [Array<String>]
        # @return [Array<String>]
        def unknown(model_ids)
          listed = catalog
          listed.nil? ? [] : model_ids - listed
        end
      end
    end
  end
end
