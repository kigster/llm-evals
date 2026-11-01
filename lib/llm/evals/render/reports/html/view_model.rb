# frozen_string_literal: true

module LLM
  module Evals
    module Render
      module Reports
        class HTML
          # What the report's page shows, worked out from a decoded snapshot; the
          # template and its markup stay with {HTML}.
          class ViewModel
            include Format

            attr_reader :report

            # @param report [JSON::Loaded]
            def initialize(report)
              @report = report
              @ranking = Ranking.new(metrics: report.metrics, weighted_score: report.weighted_score)
            end

            # @return [String]
            def report_title = "#{configuration_name} evaluation report"

            # @return [String]
            def configuration_name = report.suite

            def summaries = report.summaries

            def weighted_score = report.weighted_score

            # @return [Hash{Symbol => Object}] health counts and cost for the template
            def health_summary
              usage = summaries.map(&:usage).reduce(Usage.zero, :+)
              failed = results.count { Ranking.failed?(it) }
              { successful:    results.size - failed,
                total:         results.size,
                failed:,
                input_tokens:  tokens(usage.input_tokens),
                output_tokens: tokens(usage.output_tokens),
                cost:          money(usage.cost_usd) }
            end

            # @return [Hash{Symbol => Object}] see {GlobalStandings#to_h}
            def global_standings = GlobalStandings.new(summaries, @ranking).to_h

            # @return [Array<Hash{Symbol => Object}>] see {DatasetSection#to_h}
            def dataset_reports
              summaries.group_by(&:dataset).sort.map { |name, group| DatasetSection.new(name, group, @ranking).to_h }
            end

            # @param kase [Case]
            # @param group [Array<Experiment::Summary>]
            # @return [Array<Hash{Symbol => Object}>] runs and display values for one case
            def case_results(kase, group)
              group.flat_map(&:results).select { it.case.key == kase.key }.map do |run|
                details = run.failed? ? { "error" => run.error } : run.score&.diagnostics
                { run:, status: status(run), details: details || {} }
              end
            end

            # @param entry [Hash{Symbol => Object}]
            # @return [Float, nil]
            def ranking_value(entry) = entry[:ranking]

            # @return [String]
            def primary_metric = @ranking.primary_metric

            # @return [String]
            def weight_description
              weighted_score ? "Weighted score from the lineup; chart order runs worst to best." : "Ranked by #{primary_metric}; chart order runs worst to best."
            end

            private

            def results = summaries.flat_map(&:results)

            def status(run)
              return run.error if run.failed?
              return run.reply.error if run.reply&.error?

              run.score ? percent(run.score.value) : "No score"
            end
          end
        end
      end
    end
  end
end
