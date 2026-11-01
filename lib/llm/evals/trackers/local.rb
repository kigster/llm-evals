# frozen_string_literal: true

require "fileutils"

module LLM
  module Evals
    module Trackers
      # Always on: every experiment's results and summary land in one JSON
      # file under `log/`, so a run is never lost to a closed terminal or a
      # remote tracker that was never configured.
      class Local < Base
        attr_reader :dir, :path

        # @!attribute [r] dir
        #   @return [String] where the files go

        # @!attribute [r] path
        #   @return [String, nil] the file for this experiment; nil until {#start}

        # Holds results in memory and writes nothing until {#finish}.
        #
        # @param dir [String] where the files go; `log/llm-evals` at the repository root by default
        # @param context [Hash] see {Base#initialize}
        def initialize(dir: File.join(Dry::CLI::UI::Invocation.root(Dir.pwd), "log", "llm-evals"), **context)
          super(**context)
          @dir = dir
          @results = []
          @lock = Mutex.new
        end

        # Overrides {Base#describe}.
        #
        # @return [String] the directory
        def describe = "local: #{dir}"

        # Fixes the file name from the start time, so {#finish} needs no clock.
        #
        # @param experiment [Actions::Experiment] the experiment starting
        # @return [void]
        def start(experiment)
          @started_at = Time.now
          @path = File.join(dir, "#{slug(experiment.name)}.#{@started_at.strftime("%Y-%m-%d.%H%M%S")}.json")
        end

        # Keeps the result for {#finish}'s document.
        #
        # @param result [Results::RunResult] the finished case
        # @return [void]
        def record(result)
          @lock.synchronize { @results << result }
        end

        # Creates the directory and writes the whole document in one go.
        #
        # @param experiment [Actions::Experiment] the experiment finishing
        # @param summary [Actions::Experiment::Summary] its totals
        # @return [Hash] `url:` nil, `path:` the file written
        def finish(experiment, summary)
          FileUtils.mkdir_p(dir)
          File.write(path, JSON.pretty_generate(document(experiment, summary)))
          { url: nil, path: path }
        end

        private

        # Makes a name safe for a file name.
        #
        # @param text [String] the experiment's name
        # @return [String]
        def slug(text) = text.gsub(/[^A-Za-z0-9.-]+/, "_").squeeze("_").delete_prefix("_").delete_suffix("_")

        # The file's whole contents, with results back in case order rather than finishing order.
        #
        # @param experiment [Actions::Experiment] the experiment finishing
        # @param summary [Actions::Experiment::Summary] its totals
        # @return [Hash{Symbol => Object}]
        def document(experiment, summary)
          {
            suite:      context[:suite],
            experiment: experiment.name,
            model:      experiment.model.id,
            provider:   experiment.model.provider.name,
            settings:   experiment.model.settings,
            dataset:    experiment.dataset,
            started_at: @started_at.iso8601,
            duration:   summary.duration,
            means:      summary.means,
            errors:     summary.errors,
            usage:      summary.usage.to_h,
            results:    @lock.synchronize { @results.sort_by { experiment.cases.index(it.case) }.map { row(it) } }
          }
        end

        # One case's entry; the score and reply are nil when the case raised.
        #
        # @param result [Results::RunResult] the finished case
        # @return [Hash{Symbol => Object}]
        def row(result)
          {
            case:        result.case.key,
            duration:    result.duration,
            error:       result.error,
            score:       result.score&.value,
            metrics:     result.score&.metrics,
            outcomes:    result.score&.outcomes,
            diagnostics: result.score&.diagnostics,
            reply_error: result.reply&.error,
            usage:       result.reply&.usage&.to_h
          }
        end
      end
    end
  end
end
