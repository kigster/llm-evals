# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "uri"

module LLM
  module Evals
    module Render
      module Reports
        # Writes the canonical JSON snapshot and passes that snapshot to the
        # selected display. Temporary snapshots are removed after presentation.
        class Pipeline
          # Where a run's reports went. A path is nil for anything not kept; `browser_opened`
          # is nil when no attempt was made.
          #
          # @!attribute [r] json_path
          #   @return [String, nil] the saved snapshot; nil when it was only temporary
          # @!attribute [r] html_path
          #   @return [String, nil]
          # @!attribute [r] css_path
          #   @return [String, nil]
          # @!attribute [r] js_path
          #   @return [String, nil]
          # @!attribute [r] browser_opened
          #   @return [Boolean, nil]
          Result = Data.define(:json_path, :html_path, :css_path, :js_path, :browser_opened)

          # Reduces the project's name to a slug for use in file names.
          #
          # @param providers [Providers::Registry]
          # @param runtime [Runtime::Environment]
          # @param destination [String]
          # @param temp_dir [String]
          # @param project [String]
          def initialize(providers:, runtime:, destination:, temp_dir:, project:)
            @providers = providers
            @runtime = runtime
            @destination = destination
            @temp_dir = temp_dir
            @project = project.to_s.downcase.gsub(/[^a-z0-9]+/, "-").delete_prefix("-").delete_suffix("-")
          end

          # Decodes the snapshot back before showing it, so a live report and `render`
          # display exactly the same thing. Does nothing without autosave or a display.
          # `display` is none, tui, browser or both.
          #
          # @param summaries [Array<Actions::Experiment::Summary>]
          # @param metrics [Array<Scoring::Metric>]
          # @param weighted_score [Scoring::WeightedScore, nil]
          # @param run_options [Hash]
          # @param autosave [Boolean]
          # @param display [String]
          # @param open [Boolean]
          # @yield [report] display the decoded JSON in the terminal
          # @yieldparam report [JSON::Loaded]
          # @raise [Error] when the snapshot cannot be decoded
          # @return [Result]
          def call(summaries:, metrics:, weighted_score:, run_options:, autosave:, display:, open:)
            return Result.new(nil, nil, nil, nil, nil) unless autosave || display != "none"

            stamp = timestamp
            json_path = autosave ? artifact_path(@destination, stamp, "json") : temporary_json_path
            write_json(summaries:, metrics:, weighted_score:, run_options:, path: json_path)
            return Result.new(json_path:, html_path: nil, css_path: nil, js_path: nil, browser_opened: nil) if display == "none"

            report = JSON.decode(File.read(json_path), providers: @providers)
            yield report if block_given? && Config::TERMINAL_DISPLAYS.include?(display)
            html_path, css_path, js_path, browser_opened = render_browser(report, open:) if Config::BROWSER_DISPLAYS.include?(display)
            Result.new(json_path: autosave ? json_path : nil, html_path:, css_path:, js_path:, browser_opened:)
          ensure
            FileUtils.rm_f(json_path) if defined?(json_path) && json_path && !autosave
          end

          # The snapshot's document, to a file or back to the caller.
          #
          # @param summaries [Array<Actions::Experiment::Summary>]
          # @param metrics [Array<Scoring::Metric>]
          # @param weighted_score [Scoring::WeightedScore, nil]
          # @param run_options [Hash]
          # @param path [String, nil] nil returns JSON text to the caller
          # @return [String, nil] JSON text when no path was supplied
          def write_json(summaries:, metrics:, weighted_score:, run_options:, path:)
            document = JSON.dump(summaries, metrics:, weighted_score:, run_options:)
            if path
              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, document)
              nil
            else
              document
            end
          end

          # Rebuilds the HTML from a snapshot, standing alone with its assets embedded.
          #
          # @param json [String] serialized run results
          # @param path [String, nil] nil returns HTML text to the caller
          # @return [String, nil] HTML text when no path was supplied
          def write_html(json:, path:)
            report = JSON.decode(json, providers: @providers)
            document = HTML.render(report)
            if path
              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, document)
              nil
            else
              document
            end
          end

          # Writes an explicitly requested JSON report under the configured
          # destination, using the same timestamped name as an autosaved result.
          #
          # @param summaries [Array<Actions::Experiment::Summary>]
          # @param metrics [Array<Scoring::Metric>]
          # @param weighted_score [Scoring::WeightedScore, nil]
          # @param run_options [Hash]
          # @return [String] the saved JSON path
          def save_json(summaries:, metrics:, weighted_score:, run_options:)
            path = artifact_path(@destination, timestamp, "json")
            write_json(summaries:, metrics:, weighted_score:, run_options:, path:)
            path
          end

          # The name of a project's report, the same on every run, so the newest
          # replaces the last. The JSON beside it keeps the timestamp, and
          # `render` can rebuild any older report from it.
          #
          # @param directory [String]
          # @param extension [String] html, or the css and js that go with it
          # @return [String]
          def report_path(directory, extension = "html")
            File.join(directory, "#{@project}-llm-evals.report.#{extension}")
          end

          private

          # Writes the page and its assets next to each other, and opens it when asked.
          #
          # @param report [JSON::Loaded]
          # @param open [Boolean] whether to open the page in the browser
          # @return [Array(String, String, String, Boolean, nil)] the HTML, CSS and JS paths, and
          #   whether the browser opened; nil when `open` is false
          def render_browser(report, open:)
            FileUtils.mkdir_p(@destination)
            html_path = report_path(@destination, "html")
            css_path = report_path(@destination, "css")
            js_path = report_path(@destination, "js")
            File.write(css_path, File.read(File.join(HTML::TEMPLATE_DIRECTORY, "html_report.css")))
            File.write(js_path, File.read(File.join(HTML::TEMPLATE_DIRECTORY, "html_report.js")))
            html = HTML.render(report,
              stylesheet_path: File.basename(css_path),
              script_path:     File.basename(js_path))
            File.write(html_path, html)
            browser_opened = @runtime.browse(URI::DEFAULT_PARSER.escape("file://#{html_path}")) if open
            [html_path, css_path, js_path, browser_opened]
          end

          # Timestamped, so results accumulate rather than replace each other.
          #
          # @param directory [String]
          # @param stamp [String] see {#timestamp}
          # @param extension [String]
          # @return [String]
          def artifact_path(directory, stamp, extension)
            File.join(directory, "#{@project}.results.#{stamp}.#{extension}")
          end

          # Down to the microsecond, so runs started together do not overwrite each other.
          #
          # @return [String]
          def timestamp = Time.now.strftime("%Y-%m-%d.%H%M%S%6N")

          # Creates an empty file now to claim the name; {#call} removes it afterwards.
          #
          # @return [String] the path
          def temporary_json_path
            FileUtils.mkdir_p(@temp_dir)
            file = Tempfile.create(["#{@project}.results.", ".json"], @temp_dir)
            path = file.path
            file.close
            path
          end
        end
      end
    end
  end
end
