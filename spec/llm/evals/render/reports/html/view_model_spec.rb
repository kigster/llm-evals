# frozen_string_literal: true

RSpec.describe LLM::Evals::Render::Reports::HTML::ViewModel do
  subject(:view) { described_class.new(report) }

  let(:providers) { LLM::Evals.configuration.providers }
  let(:metric) { LLM::Evals::Scoring::Metric.new(name: "accuracy", primary: true) }
  let(:usage) { { input_tokens: 1000, output_tokens: 2, cost_usd: 0.011 } }
  let(:weighted_score) { nil }
  let(:report) do
    LLM::Evals::Render::Reports::JSON::Loaded.new(suite: "toy", generated_at: nil, run_options: {}, metrics: [metric], weighted_score:, summaries:)
  end
  let(:summaries) do
    [summary("fake/best", "one", [ok("a", 1.0), ok("b", 1.0)]),
     summary("fake/fair", "one", [ok("a", 0.5), ok("b", 0.5)]),
     summary("fake/half", "one", [ok("a", 1.0), broken("b")])]
  end

  def model(id) = LLM::Evals::Models::Model.new(id:, provider: providers.for("fake/echo"), settings: {})

  def kase(id, dataset: "one") = LLM::Evals::Datasets::Case.new(id:, dataset:, variant: "clear", input: "", expected: nil, path: "", metadata: {})

  def ok(id, value, dataset: "one")
    score = LLM::Evals::Results::Score.new(value:, metrics: { "accuracy" => value }, outcomes: {}, diagnostics: { "d" => id })
    LLM::Evals::Results::RunResult.new(experiment: nil, case: kase(id, dataset:), reply: nil, score:, duration: 1.0)
  end

  def broken(id, dataset: "one") = LLM::Evals::Results::RunResult.new(experiment: nil, case: kase(id, dataset:), reply: nil, score: nil, duration: 1.0, error: "boom")

  def summary(id, dataset, results)
    LLM::Evals::Actions::Experiment::Summary.new(model: model(id), dataset:, name: id, means: {}, results:, errors: [], duration: 2.0, permalink: nil, usage: LLM::Evals::Stats::Usage.from(usage))
  end

  it { expect(view.report_title).to eq("toy evaluation report") }
  it { expect(view.primary_metric).to eq("accuracy") }
  it { expect(view.weight_description).to start_with("Ranked by accuracy") }

  describe "#health_summary" do
    it "counts results and formats the totals" do
      expect(view.health_summary).to eq(successful: 5, total: 6, failed: 1, input_tokens: "3,000", output_tokens: "6", cost: "$0.04")
    end
  end

  describe "#global_standings" do
    let(:standings) { view.global_standings }

    it "ranks only complete contenders, worst first" do
      expect(standings[:ranked].map { it[:model].id }).to eq(%w[fake/fair fake/best])
      expect(standings[:leader][:model].id).to eq("fake/best")
    end

    it "keeps the incomplete among the entries, without a ranking" do
      half = standings[:entries].find { it[:model].id == "fake/half" }
      expect(half).to include(complete: false, successful: 1, total: 2, errors: 1)
      expect(half).not_to have_key(:ranking)
    end

    it "groups a model's datasets into one entry" do
      summaries << summary("fake/best", "two", [ok("c", 1.0, dataset: "two")])
      entry = standings[:entries].find { it[:model].id == "fake/best" }
      expect(entry).to include(total: 3, successful: 3)
      expect(entry[:row]).to include("time" => 4.0)
    end

    it "reports no leader when nothing is complete" do
      summaries.shift(2)
      expect(standings).to include(leader: nil, ranked: [])
      expect(standings[:best_coverage][:model].id).to eq("fake/half")
    end

    context "with weights" do
      let(:weighted_score) { LLM::Evals::Scoring::WeightedScore.new({ "accuracy" => -1 }, metrics: ["accuracy"]) }

      it "ranks by them, not the primary metric" do
        expect(standings[:leader][:model].id).to eq("fake/fair")
        expect(view.weight_description).to start_with("Weighted score")
      end
    end
  end

  describe "#dataset_reports" do
    let(:sections) { view.dataset_reports }

    before { summaries << summary("fake/best", "a-first", [ok("z", 1.0, dataset: "a-first")]) }

    it "gives each dataset a section, in name order" do
      expect(sections.map { it[:name] }).to eq(%w[a-first one])
    end

    it "names the winner among the complete, and sorts the rest best first" do
      section = sections.last
      expect(section[:winner][:model].id).to eq("fake/best")
      expect(section[:entries].first[:model].id).to eq("fake/best")
    end

    it "lists each case once, in order" do
      expect(sections.last[:cases].map { it.case.id }).to eq(%w[a b])
    end
  end

  describe "#case_results" do
    def status_of(result) = view.case_results(result.case, [summary("fake/x", "one", [result])]).first

    it "shows a score as a percent, with its diagnostics" do
      expect(status_of(ok("a", 0.5))).to include(status: "50.0%", details: { "d" => "a" })
    end

    it "shows a failed run's error" do
      expect(status_of(broken("a"))).to include(status: "boom", details: { "error" => "boom" })
    end

    it "shows the reply's error" do
      reply = LLM::Evals::Results::Reply.new(output: nil, raw: nil, usage: {}, error: "refused", metadata: {})
      run = LLM::Evals::Results::RunResult.new(experiment: nil, case: kase("a"), reply:, score: nil, duration: 0.0)
      expect(status_of(run)).to include(status: "refused", details: {})
    end

    it "admits a run with no score" do
      run = LLM::Evals::Results::RunResult.new(experiment: nil, case: kase("a"), reply: nil, score: nil, duration: 0.0)
      expect(status_of(run)).to include(status: "No score")
    end

    it "leaves out other cases" do
      run = ok("a", 1.0)
      expect(view.case_results(kase("other"), [summary("fake/x", "one", [run])])).to be_empty
    end
  end
end
