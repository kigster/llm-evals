# frozen_string_literal: true

RSpec.describe LLM::Evals::CallStats do
  subject(:rows) { described_class.new(summaries, seconds: 10).rows }

  let(:openrouter) { instance_double(LLM::Evals::Providers::Base, name: "openrouter", direct?: false) }
  let(:typesafe) { instance_double(LLM::Evals::Providers::Base, name: "typesafe", direct?: true) }
  let(:summaries) do
    [summary(openrouter, "anthropic/a", result(1.0), result(3.0), result(0.01, errored: true)),
     summary(openrouter, "anthropic/b", result(2.0)),
     summary(openrouter, "openai/c", result(4.0, errored: true)),
     summary(typesafe, "typesafe/jev", result(0.5))]
  end

  def result(duration, errored: false) = instance_double(LLM::Evals::RunResult, duration: duration, errored?: errored)

  def summary(provider, id, *results, label: id)
    model = instance_double(LLM::Evals::Model, provider: provider, id: id, to_s: label)
    instance_double(LLM::Evals::Experiment::Summary, model: model, results: results, worked_durations: results.reject(&:errored?).map(&:duration))
  end

  it "lists each provider, then its vendors and models, and no vendor row for a direct provider" do
    expect(rows.map(&:name)).to eq(%w[openrouter openrouter/anthropic openrouter/anthropic/a openrouter/anthropic/b
                                      openrouter/openai openrouter/openai/c typesafe typesafe/typesafe/jev])
  end

  it "counts requests and errors at each level" do
    expect(rows.first).to have_attributes(requests: 5, errors: 2, per_second: 0.5)
  end

  it "leaves failed calls out of the latency" do
    expect(rows[2]).to have_attributes(latency: 2.0, p95: 3.0)
  end

  it "has no latency when every call failed" do
    expect(rows[5]).to have_attributes(latency: nil, p95: nil)
  end

  it "leaves requests per second empty without the run's length" do
    expect(described_class.new(summaries, seconds: nil).rows.first.per_second).to be_nil
  end

  it "gives each setting of a model its own row" do
    low = summary(typesafe, "typesafe/jev", result(1.0), label: "typesafe/jev effort=low")
    high = summary(typesafe, "typesafe/jev", result(2.0), label: "typesafe/jev effort=high")
    expect(described_class.new([low, high], seconds: 1).rows.map(&:name)).to eq(["typesafe", "typesafe/typesafe/jev effort=low", "typesafe/typesafe/jev effort=high"])
  end

  describe ".for_run" do
    it "reads the run's length as recorded" do
      expect(described_class.for_run(summaries, { effective: { seconds: 10 } }).rows.first.per_second).to eq(0.5)
    end

    it "reads it back from JSON" do
      expect(described_class.for_run(summaries, { "effective" => { "seconds" => 10 } }).rows.first.per_second).to eq(0.5)
    end
  end
end
