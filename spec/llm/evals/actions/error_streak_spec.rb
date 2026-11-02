# frozen_string_literal: true

RSpec.describe LLM::Evals::Actions::ErrorStreak do
  subject(:streak) { described_class.new(limit: 2) }

  let(:failed) { instance_double(LLM::Evals::Results::RunResult, errored?: true) }
  let(:worked) { instance_double(LLM::Evals::Results::RunResult, errored?: false) }
  let(:asked) { [] }

  def record(*results, answer: true)
    results.each { |result| streak.record(result) { |failures| asked << failures; answer } }
  end

  it "does not ask below the limit" do
    record(failed)
    expect(asked).to be_empty
  end

  it "asks at the limit, with the streak" do
    record(failed, failed)
    expect(asked).to eq([[failed, failed]])
  end

  it "starts over after a success" do
    record(failed, worked, failed)
    expect(asked).to be_empty
  end

  it "counts a new streak after carrying on" do
    record(failed, failed, failed)
    expect(asked.size).to eq(1)
    expect(streak).not_to be_stopped
    record(failed)
    expect(asked.size).to eq(2)
  end

  it "stops when the answer is no" do
    record(failed, failed, answer: false)
    expect(streak).to be_stopped
    expect(streak.reason).to include("2 failed calls in a row")
  end

  it "ignores calls that finish after the stop" do
    record(failed, failed, answer: false)
    record(failed, failed)
    expect(asked.size).to eq(1)
  end

  it "stops and releases the workers when asking raises" do
    expect { streak.record(failed) { raise "x" } || streak.record(failed) { raise Interrupt } }.to raise_error(Interrupt)
    expect(streak).to be_stopped
    expect { Timeout.timeout(1) { streak.hold } }.not_to raise_error
  end

  it "holds other workers while asking, and ignores what finishes meanwhile" do
    streak.record(failed) { true }
    entered = Queue.new
    release = Queue.new
    asker = Thread.new do
      streak.record(failed) do
        entered << true
        release.pop
      end
    end
    entered.pop
    streak.record(failed) { asked << :again }
    streak.record(failed) { asked << :again }
    waiter = Thread.new { streak.hold }
    expect(waiter.join(0.05)).to be_nil
    release << true
    [asker, waiter].each { expect(it.join(1)).to be_truthy }
    expect(asked).to be_empty
  end
end
