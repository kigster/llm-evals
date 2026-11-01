# frozen_string_literal: true

module LLM
  module Evals
    module Testing
      # Serves every "fake/..." model without a network: a call answers with
      # the expected JSON of the case whose input matches the user prompt, so
      # a suite's own plumbing can be run end to end through the executable.
      #
      # `junk` names cases (by id or key) that get a non-JSON reply, and
      # `wrong` maps a case to fields to answer wrongly. `answers`, a callable
      # taking the user prompt, replaces the lookup altogether.
      class FakeProvider < Providers::Base
        # The namespace of the ids this provider claims.
        PREFIX = "fake/"
        # What every call reports having cost, so totals are predictable in a spec.
        USAGE = Stats::Usage.new(input_tokens: 100, output_tokens: 10, cost_usd: 0.001)
        # The reply a `junk` case gets.
        JUNK = "Sure! Here is my answer, in prose rather than JSON."

        # Every {#complete} call so far, with `model:`, `system:`, `user:` and `json:`, for a spec to inspect.
        #
        # @return [Array<Hash{Symbol => Object}>]
        attr_reader :calls

        # With no arguments, every case gets its expected JSON.
        #
        # @param junk [Array<String>] case ids or keys to answer with prose
        # @param wrong [Hash{String => Hash}] case id or key => fields to override
        # @param answers [#call, nil] user prompt => reply text; replaces the lookup
        # @param discovery [Datasets::Discovery, nil] where to look cases up; the configured suite's when nil
        def initialize(junk: [], wrong: {}, answers: nil, discovery: nil)
          super()
          @junk = junk
          @wrong = wrong
          @answers = answers
          @discovery = discovery
          @calls = []
          @lock = Mutex.new
        end

        # Overrides {Base#name}.
        #
        # @return [String] "fake"
        def name = "fake"
        # Overrides {Base#request_type}.
        #
        # @return [Symbol] `:prompt`
        def request_type = :prompt
        # Overrides {Base#prefix}.
        #
        # @return [String] {PREFIX}
        def prefix = PREFIX
        # Overrides {Base#env_keys}: nothing is called, so nothing is needed.
        #
        # @return [Array<String>] always empty
        def env_keys = []

        # Overrides {Base#catalog} to say so outright.
        #
        # @return [nil] any id passes verification
        def catalog = nil

        # Records the call under a lock, then answers it. Overrides {Base#complete}.
        #
        # @param model [Models::Model] the model called
        # @param system [String, nil] the system prompt, recorded only
        # @param user [String] the user prompt, which selects the case
        # @param json [Boolean] recorded only
        # @return [Results::ProviderResponse]
        def complete(model, system:, user:, json: true)
          @lock.synchronize { @calls << { model: model.id, system: system, user: user, json: json } }
          Results::ProviderResponse.new(text: @answers ? @answers.call(user) : answer(user), usage: USAGE)
        end

        private

        # Looks the case up by its input. A prompt matching no case gets "{}".
        #
        # @param user [String] the user prompt
        # @return [String] prose for a `junk` case; otherwise JSON, with `wrong` merged in
        def answer(user)
          kase = discovery.all.find { it.input == user }
          return "{}" if kase.nil?
          return JUNK if @junk.include?(kase.id) || @junk.include?(kase.key)

          wrong = @wrong[kase.id] || @wrong[kase.key] || {}
          JSON.generate(kase.expected.is_a?(Hash) ? kase.expected.merge(wrong) : kase.expected)
        end

        # The injected discovery, or the configured suite's when none was given.
        #
        # @return [Datasets::Discovery]
        def discovery = @discovery || LLM::Evals.configuration.discovery
      end
    end
  end
end
