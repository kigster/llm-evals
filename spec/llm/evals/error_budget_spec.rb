# frozen_string_literal: true

RSpec.describe LLM::Evals::ErrorBudget do
  subject(:budget) { described_class.new(total: 2, percent: percent) }

  let(:percent) { 60 }
  let(:good) { instance_double(LLM::Evals::RunResult, errored?: false) }
  let(:bad) { instance_double(LLM::Evals::RunResult, errored?: true) }

  def record(*results) = results.each { budget.record(it) }

  it "is not spent below the total, even at 100%" do
    record(bad)
    expect(budget).not_to be_spent
  end

  it "is not spent at the total while the share is below the percent" do
    record(good, good, bad, bad)
    expect(budget).not_to be_spent
  end

  it "is spent when both are met" do
    record(good, bad, bad)
    expect(budget).to be_spent
  end

  it "stays spent after later successes" do
    record(bad, bad, good, good, good)
    expect(budget).to be_spent
  end

  context "without a percent" do
    let(:percent) { nil }

    it "is spent at the total, whatever the share" do
      record(good, good, good, bad, bad)
      expect(budget).to be_spent
    end
  end

  it "says what happened" do
    record(bad, bad)
    expect(budget.reason).to include("2 of 2 finished calls failed", "2 errors at 60%")
  end
end
