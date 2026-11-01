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
        Snapshot = Data.define(:summaries, :metrics, :weighted_score, :run_options, :results, :output, :open) do
          # @return [Hash] what {Render::Reports::Pipeline} serializes
          def document = { summaries:, metrics:, weighted_score:, run_options: }
        end

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

        # @param summaries [Array<Actions::Experiment::Summary>]
        # @param metrics [Array<Scoring::Metric>]
        # @param weighted_score [Scoring::WeightedScore, nil]
        # @param run_options [Hash]
        # @param output [String, nil] what -o was given: nil, "-", "" for the default file, or a path
        # @param open [Boolean]
        # @param format [String, nil] `tui`, `html` or `json`
        # @yield [report] draw the decoded report in the terminal
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

        private

        def strategy(format)
          case format
          when "html" then HtmlOutput
          when "json" then JsonOutput
          else PipelineOutput
          end
        end

        # The flags over the lineup's results section.
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
