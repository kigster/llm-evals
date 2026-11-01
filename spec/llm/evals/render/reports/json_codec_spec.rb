# frozen_string_literal: true

RSpec.describe LLM::Evals::Render::Reports::JSON do
  let(:providers) { LLM::Evals.configuration.providers }
  let(:model) { LLM::Evals::Model.new(id: "fake/echo", provider: providers.for("fake/echo"), settings: { effort: "low" }) }
  let(:experiment) { LLM::Evals::Render::Reports::JSON::SavedExperiment.new(model:) }
  let(:kase) { LLM::Evals::Case.new(id: "clear/001", dataset: "colors", variant: "clear", input: "i", expected: { "a" => 1 }, path: "/p", metadata: { number: 1 }) }
  let(:score) { LLM::Evals::Score.new(value: 0.5, metrics: { "accuracy" => 0.5 }, outcomes: { "a" => true }, diagnostics: { "d" => "x" }) }
  let(:reply) { LLM::Evals::Reply.new(output: { "a" => 1 }, raw: "raw", usage: { input_tokens: 1, output_tokens: 2, cost_usd: 0.5 }, error: nil, metadata: { "m" => 1 }) }
  let(:scored) { LLM::Evals::RunResult.new(experiment:, case: kase, reply:, score:, duration: 0.25) }
  let(:summary) do
    LLM::Evals::Experiment::Summary.new(model:,
      dataset: "colors",
      name: "exp",
      means: { "accuracy" => 0.5 },
      results: [scored, failed],
      errors: ["boom"],
      duration: 0.75,
      permalink: "http://x",
      usage: reply.usage)
  end
  let(:metric) { LLM::Evals::Metric.new(name: "accuracy", description: "right", primary: true) }

  def failed = LLM::Evals::RunResult.new(experiment:, case: kase, reply: nil, score: nil, duration: 0.5, error: "boom")

  def encode(weighted_score: nil, run_options: { effective: { tracker: :none, list: [:a] } })
    LLM::Evals::Render::Reports::JSON::Encoder.new([summary], metrics: [metric], weighted_score:, run_options:, suite: "suite").call
  end

  def decode(source = encode) = LLM::Evals::Render::Reports::JSON::Decoder.new(providers:).call(source)

  describe described_class::Encoder do
    let(:document) { JSON.parse(encode) }

    it "stamps the format and the suite" do
      expect(document).to include("format" => "llm-evals-report", "version" => 1, "suite" => "suite", "weights" => nil)
    end

    it "turns the run options into plain JSON" do
      expect(document["run_options"]).to eq("effective" => { "tracker" => "none", "list" => ["a"] })
    end

    it "writes a failed result with no reply or score" do
      expect(document["summaries"].first["results"].last).to include("reply" => nil, "score" => nil, "error" => "boom")
    end

    it "writes the weights when there are some" do
      weighted = LLM::Evals::WeightedScore.new({ "accuracy" => 1 }, metrics: ["accuracy"])
      expect(JSON.parse(encode(weighted_score: weighted))["weights"]).to eq("accuracy" => 1)
    end
  end

  describe described_class::Decoder do
    it "reads back what was encoded" do
      loaded = decode
      expect(loaded).to have_attributes(suite: "suite", metrics: [metric], weighted_score: nil)
      expect(loaded.summaries.first).to have_attributes(dataset: "colors", name: "exp", errors: ["boom"], duration: 0.75, permalink: "http://x")
    end

    it "restores the model through its provider" do
      expect(decode.summaries.first.model).to have_attributes(id: "fake/echo", provider: model.provider, effort: "low")
    end

    it "restores a scored result, and the case's metadata keys" do
      result = decode.summaries.first.results.first
      expect(result.case.metadata).to eq(number: 1)
      expect(result.case.path).to eq("")
      expect(result.reply).to have_attributes(raw: "raw", metadata: { "m" => 1 })
      expect(result.score).to have_attributes(value: 0.5, metrics: { "accuracy" => 0.5 }, diagnostics: { "d" => "x" })
    end

    it "restores a failed result with nothing to score" do
      expect(decode.summaries.first.results.last).to have_attributes(reply: nil, score: nil, error: "boom", duration: 0.5)
    end

    it "rebuilds the weights" do
      weighted = LLM::Evals::WeightedScore.new({ "accuracy" => 1 }, metrics: ["accuracy"])
      expect(decode(encode(weighted_score: weighted)).weighted_score.weights).to eq("accuracy" => 1)
    end

    it "ignores empty weights" do
      expect(decode(JSON.generate(JSON.parse(encode).merge("weights" => {}))).weighted_score).to be_nil
    end

    it "fills in what an older report leaves out" do
      minimal = { format: "llm-evals-report", version: 1, metrics: [{ name: "a" }], summaries: [] }
      expect(decode(JSON.generate(minimal))).to have_attributes(suite: "llm-evals", run_options: {}, summaries: [])
      expect(decode(JSON.generate(minimal)).metrics.first).to have_attributes(description: "", aggregate: :mean, primary: false)
    end

    it { expect { decode("{}") }.to raise_error(LLM::Evals::Error, /unsupported report format version/) }
    it { expect { decode("nope") }.to raise_error(LLM::Evals::Error, /invalid report JSON/) }
  end
end
