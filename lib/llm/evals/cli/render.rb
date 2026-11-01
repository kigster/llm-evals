# frozen_string_literal: true

module LLM
  module Evals
    module CLI
      # Turns a saved JSON run into a standalone HTML report without calling a model.
      class Render < Command
        desc "Render a saved JSON eval report as standalone HTML"

        argument :input, required: true, desc: "JSON report file produced by run or compare --format json"
        option :output, aliases: ["-o"], desc: "HTML output path (default: log/<project>-llm-evals.report.html)"

        def call(input:, output: nil, **)
          source = File.read(input)
          saved = LLM::Evals::Render::Reports::JSON.decode(source, providers: configuration.providers)
          default = output.nil? || output.empty?
          path = output == "-" || default ? nil : invocation.report_path(output)
          pipeline = LLM::Evals::Render::Reports::Pipeline.new(providers: configuration.providers,
            runtime: configuration.runtime,
            destination: File.dirname(path || input),
            temp_dir: File.dirname(input),
            project: saved.run_options.dig("effective", "project") || saved.suite)
          path = pipeline.report_path(File.dirname(invocation.report_path(""))) if default
          document = pipeline.write_html(json: source, path:)
          out.write(document) unless path
          status_box(:success, "HTML report written to #{relative(path)}", stream: err) if path
        end
      end
    end
  end
end
