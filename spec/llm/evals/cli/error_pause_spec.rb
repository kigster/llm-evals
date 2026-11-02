# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::ErrorPause do
  subject(:pause) { described_class.new(console:, notice: ->(_level, text) { notices << text }, runs:, yes:, interactive:) }

  let(:notices) { [] }
  let(:console) { instance_double(Dry::CLI::UI::Console, confirm: true) }
  let(:yes) { false }
  let(:interactive) { true }
  let(:cases) do
    %w[one two three].map { |id| instance_double(LLM::Evals::Datasets::Case, dataset: "ds", key: "ds/#{id}") }
  end
  let(:bad) { experiment("bad/model") }
  let(:good) { experiment("good/model") }
  let(:runs) { [bad, good] }
  let(:failures) { cases.first(2).map { failure(bad, it, "401 bad key") } }
  let(:text) { notices.join }

  def experiment(id)
    instance_double(LLM::Evals::Actions::Experiment, model: instance_double(LLM::Evals::Models::Model, id:), dataset: "ds", cases:)
  end

  def failure(run, kase, error) = instance_double(LLM::Evals::Results::RunResult, experiment: run, case: kase, error:, reply: nil)

  it "describes the errors and what they touch" do
    pause.call(failures)
    expect(text).to include("2 calls in a row failed",
      "2 x 401 bad key",
      "Models: 1 of 2 affected: bad/model",
      "Datasets: all 1 affected",
      "Cases: 2 of 3 affected: ds/one, ds/two",
      "have not run yet")
  end

  it "says all when everything is affected" do
    pause.call(cases.product(runs).map { |kase, run| failure(run, kase, "boom") })
    expect(text).to include("Models: all 2 affected", "Datasets: all 1 affected", "Cases: all 3 affected")
    expect(text).not_to include("have not run yet")
  end

  it "reads a message from a reply the model failed" do
    reply = instance_double(LLM::Evals::Results::Reply, error: "refused")
    pause.call([instance_double(LLM::Evals::Results::RunResult, experiment: bad, case: cases.first, error: nil, reply:)])
    expect(text).to include("1 x refused")
  end

  it "shows the commonest messages and counts the others" do
    pause.call(%w[a a b c d e].map { failure(bad, cases.first, it) })
    expect(text).to include("2 x a", "1 x b", "1 x c", "and 2 other errors")
    expect(text).not_to include("1 x d")
  end

  it "shortens a long list of names" do
    many = Array.new(8) { |i| instance_double(LLM::Evals::Datasets::Case, dataset: "ds", key: "ds/#{i}") }
    allow(bad).to receive(:cases).and_return(many + cases)
    allow(good).to receive(:cases).and_return(many + cases)
    pause.call(many.map { failure(bad, it, "x") })
    expect(text).to include("Cases: 8 of 11 affected: ds/0, ds/1, ds/2, ds/3, ds/4 and 3 more")
  end

  it "answers with what the user chose" do
    allow(console).to receive(:confirm).and_return(false)
    expect(pause.call(failures)).to be(false)
    expect(console).to have_received(:confirm).with("Keep running?", default: false)
  end

  context "with --yes" do
    let(:yes) { true }

    it "carries on without asking, and still says why" do
      expect(pause.call(failures)).to be(true)
      expect(console).not_to have_received(:confirm)
      expect(text).to include("401 bad key")
    end
  end

  context "with nobody to ask" do
    let(:interactive) { false }

    it "stops without asking, and still says why" do
      expect(pause.call(failures)).to be(false)
      expect(console).not_to have_received(:confirm)
      expect(text).to include("401 bad key")
    end
  end
end
