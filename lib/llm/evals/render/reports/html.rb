# frozen_string_literal: true

require "cgi"
require "erb"
require "forwardable"
require "json"

module LLM
  module Evals
    module Render
      module Reports
        # Builds a self-contained HTML report for completed eval runs.
        # Only contenders with full, error-free coverage can lead the report.
        class HTML
          extend Forwardable
          include Format

          # Directory containing the report template and its embedded assets.
          TEMPLATE_DIRECTORY = File.expand_path("../../templates", __dir__)

          # @param report [JSON::Loaded] decoded from a saved JSON snapshot
          # @return [String]
          def self.render(report, stylesheet_path: nil, script_path: nil)
            new(report, stylesheet_path:, script_path:).render
          end

          attr_reader :report, :stylesheet_path, :script_path

          # @param report [JSON::Loaded] decoded from a saved JSON snapshot
          def initialize(report, stylesheet_path: nil, script_path: nil)
            @report = report
            @stylesheet_path = stylesheet_path
            @script_path = script_path
          end

          # Renders the template with report data and embedded assets.
          #
          # @return [String]
          def render
            health = view.health_summary
            standings = view.global_standings
            datasets = view.dataset_reports
            ERB.new(File.read(template_path), trim_mode: "-").result(binding)
          end

          private

          def_delegators :view,
            :report_title,
            :configuration_name,
            :summaries,
            :weighted_score,
            :case_results,
            :ranking_value,
            :primary_metric,
            :weight_description

          def view = @view ||= ViewModel.new(report)

          # @param model [Model]
          # @return [Array<String>] HTML-escaped provider and model names
          def model_parts(model)
            provider, name = model.id.to_s.split("/", 2)
            [escape(provider), escape(name || provider)]
          end

          # @param model [Model]
          # @return [String] escaped effort setting, or `default`
          def effort_label(model) = escape(model.effort || "default")

          # @param model [Model]
          # @return [String] escaped temperature setting, or `default`
          def temperature_label(model) = escape(model.temperature.nil? ? "default" : model.temperature)

          # @param value [Object]
          # @return [String]
          def pretty(value) = ::JSON.pretty_generate(value)

          # @param value [Object]
          # @return [String] HTML-escaped text
          def escape(value) = CGI.escapeHTML(value.to_s)

          # @return [String]
          def stylesheet = asset("html_report.css")

          def stylesheet_tag
            stylesheet_path ? %(<link rel="stylesheet" href="#{escape(stylesheet_path)}">) : "<style>#{stylesheet}</style>"
          end

          # @return [String]
          def sorting_script = asset("html_report.js")

          def script_tag
            script_path ? %(<script src="#{escape(script_path)}"></script>) : "<script>#{sorting_script}</script>"
          end

          # Reads one packaged asset for embedding in the standalone report.
          #
          # @param name [String] report asset filename
          # @return [String]
          def asset(name) = File.read(File.join(TEMPLATE_DIRECTORY, name))

          # @return [String]
          def template_path = File.join(TEMPLATE_DIRECTORY, "html_report.html.erb")
        end
      end
    end
  end
end
