# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::RunRecord do
  subject(:record) do
    described_class.new(command: "run", cli:, config:, planner:, trackers:, providers:, contenders: [contender], datasets: ["colors"], runs:, seconds: 1.5).to_h
  end

  let(:cli) { { models: [], local: false } }
  let(:config) { instance_double(LLM::Evals::Config, request_types: [:prompt], defaults: { "parallelism" => 4 }) }
  let(:planner) { instance_double(LLM::Evals::CLI::RunPlanner, parallelism: 4, concurrency: 2) }
  let(:remote) { class_double(LLM::Evals::Tracker, tracker_name: "braintrust") }
  let(:trackers) { instance_double(LLM::Evals::CLI::TrackerResolver, project: "p", remote:) }
  let(:provider) { instance_double(LLM::Evals::Providers::Base, name: "fake") }
  let(:providers) { instance_double(LLM::Evals::Providers::Registry, for: provider) }
  let(:contender) { LLM::Evals::Contender.new(model: "fake/echo", effort: "low", temperature: 0.2, max_tokens: 10) }
  let(:kase) { instance_double(LLM::Evals::Case, id: "clear/001") }
  let(:runs) { Array.new(2) { instance_double(LLM::Evals::Experiment, dataset: "colors", cases: [kase]) } }

  it "keeps the flags as they were given" do
    expect(record).to include(command: "run", cli:)
  end

  it "records what reached the experiments" do
    expect(record[:effective]).to include(project: "p", request_types: ["prompt"], datasets: ["colors"], parallelism: 4, concurrency: 2, tracker: "braintrust", seconds: 1.5)
  end

  it "lists each dataset's cases once" do
    expect(record[:effective][:cases]).to eq("colors" => ["clear/001"])
  end

  it "records each contender's settings and provider" do
    expect(record[:effective][:contenders]).to eq([{ model: "fake/echo", provider: "fake", effort: "low", temperature: 0.2, max_tokens: 10 }])
  end

  context "with --local" do
    let(:cli) { { local: true } }

    it { expect(record[:effective][:tracker]).to eq("none") }
  end

  context "with no remote tracker" do
    let(:remote) { nil }

    it { expect(record[:effective][:tracker]).to be_nil }
  end
end
