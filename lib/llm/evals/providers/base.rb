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
        # @raise [NotImplementedError] unless a subclass overrides it
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

        # Dasherized from the class name; a subclass overrides it when the brand is
        # spelled differently.
        #
        # @return [String] short name, for messages and the leaderboard
        def name = self.class.name.split("::").last.gsub(/([a-z\d])([A-Z])/, '\1-\2').downcase

        # Matches on {#prefix}, so most subclasses override that instead of this.
        #
        # @param model_id [String] as the lineup names it
        # @return [Boolean] whether this provider serves the model
        def serves?(model_id) = model_id.start_with?(prefix)

        # Overridden by a subclass whose ids share a namespace.
        #
        # @return [String] the id prefix this provider claims; "" claims everything
        def prefix = ""

        # Strips {#prefix}, so the lineup's namespacing never reaches the API.
        #
        # @param model_id [String]
        # @return [String] the id as the provider's API knows it
        def model_name(model_id) = model_id.delete_prefix(prefix)

        # {Registry#keys_for} collects these across the lineup.
        #
        # @return [Array<String>] environment variables a run through this provider needs
        def env_keys = []

        # {EFFORTS} unless a subclass narrows or empties it.
        #
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
        # @overload setup!(app_name:)
        #   @param app_name [String] what the client tells the API the caller is
        #   @return [void]
        def setup!(**) = nil

        # One chat completion, for a provider of request type `prompt`.
        #
        # @param model [Models::Model] the model and settings to call
        # @param system [String, nil] the system prompt, if any
        # @param user [String] the user prompt
        # @param json [Boolean] whether to ask for a JSON object reply
        # @return [Results::ProviderResponse]
        # @raise [NotImplementedError] unless a subclass overrides it
        def complete(model, system:, user:, json: true)
          raise NotImplementedError, "#{self.class}#complete must return an LLM::Evals::Results::ProviderResponse"
        end

        # One request of typed questions, for a provider whose API answers them.
        #
        # @param model [Models::Model] the model to ask
        # @param state [Object] what the questions are about; any JSON-encodable value
        # @param questions [Hash{String => Hash}] by name
        # @return [Results::ProviderResponse]
        # @raise [NotImplementedError] unless a subclass overrides it
        def ask(model, state:, questions:)
          raise NotImplementedError, "#{self.class} does not answer typed questions"
        end

        # {Models::Throttle} asks this after a failed call; false by default, so a
        # provider that says nothing is never retried.
        #
        # @param _error [StandardError] what a call raised
        # @return [Boolean] whether the same call may work later
        def retryable?(_error) = false

        # {Models::Throttle} uses this instead of its own backoff when it is not nil.
        #
        # @param _error [StandardError] what a call raised
        # @return [Numeric, nil] the seconds the API asked to wait, if it did
        def retry_after(_error) = nil

        # Builds the callable model for a lineup entry, on this provider.
        #
        # @param contender [Models::Contender] the lineup entry
        # @param throttle [Models::Throttle] what the model's calls pass through
        # @return [Models::Model]
        def model_for(contender, throttle: Models::Throttle.new) = Models::Model.new(id: contender.model, provider: self, settings: contender.settings, throttle:)

        # Every id in `model_ids` the provider does not list.
        #
        # @param model_ids [Array<String>] ids as the lineup names them
        # @return [Array<String>] none when the provider cannot list its models
        def unknown(model_ids)
          listed = catalog
          listed.nil? ? [] : model_ids - listed
        end
      end
    end
  end
end
