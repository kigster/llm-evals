# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Sends a finished run to the output its format asks for: an HTML page, a
      # JSON document, or, with no format, whatever the lineup's results section
      # configures. The command keeps the terminal view, which draws on its own
      # streams, and hands it over as a block.
      class ReportDispatcher
        # What --format asks of results.display.
        DISPLAYS = { "tui" => "tui", "none" => "none", "html" => "browser", "json" => "none" }.freeze

        # One run on its way out.
        #
        # @!attribute [r] summaries
        #   @return [Array<Actions::Experiment::Summary>]
        # @!attribute [r] metrics
        #   @return [Array<Scoring::Metric>]
        # @!attribute [r] weighted_score
        #   @return [Scoring::WeightedScore, nil]
        # @!attribute [r] run_options
        #   @return [Hash] what the saved report says about its run, results included
        # @!attribute [r] results
        #   @return [Hash{Symbol => Object}] the settled autosave, destination, temp_dir and display
        # @!attribute [r] output
        #   @return [String, nil] what -o was given
        # @!attribute [r] open
        #   @return [Boolean] whether to open what gets written
        Snapshot = Data.define(:summaries, :metrics, :weighted_score, :run_options, :results, :output, :open) do
          # Leaves out how and where it is delivered, which the saved JSON has no use for.
          #
          # @return [Hash] what {Render::Reports::Pipeline} serializes
          def document = { summaries:, metrics:, weighted_score:, run_options: }
        end

        # Holds only collaborators; nothing is written until {#call}.
        #
        # @param config [Config]
        # @param options [Hash] the parsed flags
        # @param providers [Providers::Registry]
        # @param runtime [Runtime::Environment]
        # @param suite [String] names the files when the run has no project
        # @param console [Console]
        # @param invocation [Dry::CLI::UI::Invocation]
        def initialize(config:, options:, providers:, runtime:, suite:, console:, invocation:)
          @config = config
          @options = options
          @providers = providers
          @runtime = runtime
          @suite = suite
          @console = console
          @invocation = invocation
        end

        # Picks the output for the format and hands it the snapshot.
        #
        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param metrics [Array<Scoring::Metric>]
        # @param weighted_score [Scoring::WeightedScore, nil]
        # @param run_options [Hash]
        # @param output [String, nil] what -o was given: nil, "-", "" for the default file, or a path
        # @param open [Boolean]
        # @param format [String, nil] `tui`, `html` or `json`
        # @param terminal [Proc] the block below
        # @yield [report] draw the decoded report in the terminal
        # @yieldparam report [LLM::Evals::Render::Reports::JSON::Loaded]
        # @return [void]
        def call(summaries, metrics:, weighted_score:, run_options:, output:, open:, format: nil, &terminal)
          results = effective_results(format)
          snapshot = Snapshot.new(summaries:,
            metrics:,
            weighted_score:,
            output:,
            open:,
            results:,
            run_options: run_options.merge(results:))
          strategy(format).new(pipeline: pipeline(results, run_options), console: @console, invocation: @invocation)
                          .write(snapshot, &terminal)
        end

        # Lets the command tell in advance whether the terminal view will draw.
        #
        # @param format [String, nil] `tui`, `html` or `json`
        # @return [String] the display this run settles on
        def display(format = nil) = effective_results(format)[:display]

        private

        # Anything but html or json leaves the choice to the lineup.
        #
        # @param format [String, nil] `tui`, `html` or `json`
        # @return [Class<Output>]
        def strategy(format)
          case format
          when "html" then HtmlOutput
          when "json" then JsonOutput
          else PipelineOutput
          end
        end

        # The flags over the lineup's results section.
        #
        # @param format [String, nil] `tui`, `html` or `json`, which outranks --display
        # @return [Hash{Symbol => Object}] autosave, destination, temp_dir and display
        def effective_results(format)
          configured = @config.results
          results = {
            autosave:    @options[:autosave].nil? ? configured.autosave : @options[:autosave],
            destination: File.expand_path(@options[:destination] || configured.destination),
            temp_dir:    File.expand_path(@options[:temp_dir] || configured.temp_dir),
            display:     @options[:display] || configured.display_mode
          }
          results[:display] = DISPLAYS.fetch(format, results[:display]) if format
          results
        end

        # Looks the project up under symbol and string keys alike, and falls back on the suite's name.
        #
        # @param results [Hash{Symbol => Object}] from {#effective_results}
        # @param run_options [Hash]
        # @return [LLM::Evals::Render::Reports::Pipeline]
        def pipeline(results, run_options)
          LLM::Evals::Render::Reports::Pipeline.new(providers: @providers,
            runtime:     @runtime,
            destination: results[:destination],
            temp_dir:    results[:temp_dir],
            project:     run_options.dig(:effective, :project) || run_options.dig("effective", "project") || @suite)
        end
      end
    end
  end
end
