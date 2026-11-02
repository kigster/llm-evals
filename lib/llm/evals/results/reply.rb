# frozen_string_literal: true

module LLM
  module Evals
    module Results
      # What an {Actions::Adapter} returns for one case. `error` is the model's failure
      # (it did not answer the question: no JSON, a refusal) and scores 0; a
      # transport failure is not the model's and is raised instead, so it is
      # counted as an error of the run rather than a wrong answer.
      #
      # @!attribute [r] output
      #   @return [Object, nil] the adapter's parsed answer, usually a Hash; nil when the model failed
      # @!attribute [r] raw
      #   @return [String, nil] the reply as the model gave it
      # @!attribute [r] usage
      #   @return [Stats::Usage] what the call cost
      # @!attribute [r] error
      #   @return [String, nil] why the model failed to answer
      # @!attribute [r] metadata
      #   @return [Hash] anything else the adapter wants kept with the reply
      Reply = Data.define(:output, :raw, :usage, :error, :metadata) do
        # Normalizes the usage, so a Hash read back from a snapshot is accepted.
        #
        # @param output [Object, nil] the adapter's parsed answer
        # @param raw [String, nil] the reply as the model gave it
        # @param usage [Stats::Usage, Hash, nil] what the call cost; see {Stats::Usage.from}
        # @param error [String, nil] why the model failed to answer
        # @param metadata [Hash] anything else the adapter wants kept with the reply
        def initialize(output: nil, raw: nil, usage: Stats::Usage.zero, error: nil, metadata: {})
          super(output: output, raw: raw, usage: Stats::Usage.from(usage), error: error, metadata: metadata)
        end

        # @return [Boolean] whether the model failed to answer
        def error? = !error.nil?
      end
    end
  end
end
