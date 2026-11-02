# frozen_string_literal: true

module LLM
  module Evals
    module Providers
      # The providers in use. A contender outside a direct provider's section goes to the first
      # provider that serves its id, asked last-registered first, so a
      # suite's own transport beats the defaults and OpenRouter, which claims
      # everything, is always last. A direct contender goes to the
      # provider it names, and a direct provider is never asked about an id.
      class Registry
        include Enumerable

        # OpenRouter comes first in the list because the last is asked first.
        #
        # @return [Registry] TypeSafe, then OpenRouter for everything else
        def self.default = new([OpenRouter.new, TypeSafe.new])

        # The array is copied, so registering later does not touch the caller's.
        #
        # @param providers [Array<Base>] the last one is asked first
        def initialize(providers = [])
          @providers = providers.dup
        end

        # Registering a provider under a name already taken replaces it, so a
        # helper and a required file that both register the same provider
        # leave one, not two that would be asked twice.
        #
        # @param provider [Base] the provider to add
        # @return [Base] the provider
        def register(provider)
          @providers.reject! { it.name == provider.name }
          @providers << provider
          provider
        end

        # Walks the providers in asking order, last-registered first, which is what
        # every Enumerable lookup in this class relies on.
        #
        # @yieldparam provider [Base] each provider
        # @return [Array<Base>, Enumerator] the reversed list; an Enumerator without a block
        def each(&) = @providers.reverse.each(&)

        # Picks the provider for a lineup entry or a bare id, by the rules above.
        #
        # @param target [Models::Contender, String] a contender, or a model id
        # @return [Base]
        # @raise [Error] when no provider serves it
        def for(target)
          return direct(target.provider) if target.is_a?(Models::Contender) && target.direct?

          model_id = target.is_a?(Models::Contender) ? target.model : target
          find { !it.direct? && it.serves?(model_id) } ||
            raise(Error, "no provider serves #{model_id.inspect}; have #{reject(&:direct?).map(&:name).join(", ")}")
        end

        # Finds a direct provider by its lineup section name.
        #
        # @param name [Symbol, String] a direct provider's section
        # @return [Base]
        # @raise [Error] when no direct provider has the name
        def direct(name)
          find { it.direct? && it.name == name.to_s } ||
            raise(Error, "no direct provider #{name.to_s.inspect}; have #{direct_names.join(", ")}")
        end

        # For {#direct}'s error message.
        #
        # @return [Array<String>] the direct providers' names
        def direct_names = select(&:direct?).map(&:name)

        # Deduplicated, so each provider's setup runs once.
        #
        # @param contenders [Array<Models::Contender>] the lineup
        # @return [Array<Base>] each provider the contenders use, once
        def used_by(contenders) = contenders.map { self.for(it) }.uniq

        # Deduplicated across providers that share a key.
        #
        # @param contenders [Array<Models::Contender>] the lineup
        # @return [Array<String>] the API keys the contenders' providers need
        def keys_for(contenders) = used_by(contenders).flat_map(&:env_keys).uniq

        # Routes the contender with {#for}, then lets its provider build the model.
        #
        # @param contender [Models::Contender] the lineup entry
        # @param throttle [Models::Throttle] what the model's calls pass through
        # @return [Models::Model]
        def model_for(contender, throttle: Models::Throttle.new) = self.for(contender).model_for(contender, throttle:)

        # One refused contender: who, and why.
        #
        # @!attribute [r] contender
        #   @return [Models::Contender] the contender left out of the run
        # @!attribute [r] reason
        #   @return [String] the request type it needs, against what the suite produces
        Refusal = Data.define(:contender, :reason) do
          # The line a warning prints.
          #
          # @return [String]
          def to_s = "#{contender.model} refused: #{reason}"
        end

        # Splits the contenders into those whose provider produces a request
        # type the suite declares and those it does not. A refused contender
        # is named, never run, and never scored 0: a model the suite cannot
        # even ask is not a model that answered wrongly.
        #
        # @param contenders [Array<Models::Contender>] the lineup
        # @param request_types [Array<Symbol>] what the suite's config declares
        # @return [Array(Array<Models::Contender>, Array<Refusal>)] admitted, refused
        # @raise [Error] when no provider serves a contender
        def admit(contenders, request_types:)
          admitted, refused = contenders.partition { request_types.include?(self.for(it).request_type) }
          refusals = refused.map do |contender|
            needs = self.for(contender).request_type
            Refusal.new(contender: contender, reason: "needs #{needs}; this suite produces #{request_types.join(", ")}")
          end
          [admitted, refusals]
        end

        # Providers disagree on efforts, so this is the union of them.
        #
        # @return [Array<String>] every effort any provider accepts, for the flag's help
        def efforts = flat_map(&:efforts).uniq

        # Asks each provider in use for its catalog, and names every model it
        # does not list.
        #
        # @param contenders [Array<Models::Contender>] the lineup
        # @return [void]
        # @raise [Error] naming every unknown model
        def verify!(contenders)
          unknown = contenders.uniq(&:key).group_by { self.for(it) }.flat_map { |provider, list| provider.unknown(list.map(&:model)) }
          return if unknown.empty?

          raise Error,
            "unknown model#{"s" if unknown.size > 1} #{unknown.join(", ")}: not listed by its provider; " \
            "check the id in .llm-evals.config.yml or -m"
        end
      end
    end
  end
end
