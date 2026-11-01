# frozen_string_literal: true

# A tracker that remembers every callback, for specs that watch the run.
class RecordingTracker < LLM::Evals::Trackers::Base
  # @return [String, nil]
  def self.env_key = "RECORDING_TRACKER_KEY"

  attr_reader :events, :url

  # @param [TrueClass] enabled
  # @param [nil] url
  # @param [Hash] context
  # @return [Array]
  def initialize(url: nil, enabled: true, **context)
    super(**context)
    @url = url
    @enabled = enabled
    @events = []
  end

  # @return [TrueClass, FalseClass]
  def enabled? = @enabled

  # @return [Array<[Symbol, untyped]>]
  def start(experiment) = @events << [:start, experiment]

  # @return [Array<[Symbol, untyped]>]
  def record(result) = @events << [:record, result]

  # @return [Hash{Symbol->Unknown}]
  def finish(_experiment, summary)
    @events << [:finish, summary]
    { url: @url }
  end
end
