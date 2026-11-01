# frozen_string_literal: true

RSpec.describe LLM::Evals::Throttle do
  subject(:throttle) { described_class.new(limits, sleeper: ->(seconds) { naps << seconds; now.call(seconds) }) }

  let(:limits) { {} }
  let(:naps) { [] }
  let(:clock) { [1000.0] }
  let(:now) { ->(seconds) { clock[0] += seconds } }
  let(:provider) do
    instance_double(LLM::Evals::Providers::Base, name: "openrouter", retryable?: true, retry_after: nil)
  end
  let(:model) { instance_double(LLM::Evals::Model, name: "anthropic/claude", provider: provider) }

  before { allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock[0] } }

  def limit = instance_double(described_class::Limit, acquire: nil)

  it "returns what the call returns" do
    expect(throttle.call(model) { :reply }).to eq(:reply)
  end

  context "with limits at every level" do
    let(:limits) { { "openrouter" => limit, "openrouter/anthropic" => limit, "openrouter/anthropic/claude" => limit, "openrouter/openai" => limit } }

    it "waits on those that match, narrowest first" do
      throttle.call(model) { :reply }
      expect(limits["openrouter/anthropic/claude"]).to have_received(:acquire).ordered
      expect(limits["openrouter/anthropic"]).to have_received(:acquire).ordered
      expect(limits["openrouter"]).to have_received(:acquire).ordered
      expect(limits["openrouter/openai"]).not_to have_received(:acquire)
    end

    it "takes a slot for each attempt" do
      attempts = 0
      throttle.call(model) { (attempts += 1) == 1 ? raise(IOError) : :reply }
      expect(limits["openrouter"]).to have_received(:acquire).twice
    end
  end

  context "when the call keeps failing" do
    it "backs off, then gives up with the error" do
      attempts = 0
      expect { throttle.call(model) { attempts += 1; raise IOError } }.to raise_error(IOError)
      expect(attempts).to eq(described_class::MAX_ATTEMPTS)
      expect(naps).to eq([1.0, 2.0, 4.0, 8.0])
    end
  end

  context "when the error cannot be retried" do
    before { allow(provider).to receive(:retryable?).and_return(false) }

    it "raises at once" do
      attempts = 0
      expect { throttle.call(model) { attempts += 1; raise IOError } }.to raise_error(IOError)
      expect(attempts).to eq(1)
    end
  end

  context "when the provider says how long to wait" do
    before { allow(provider).to receive(:retry_after).and_return(7) }

    it "waits that long" do
      attempts = 0
      throttle.call(model) { (attempts += 1) == 1 ? raise(IOError) : :reply }
      expect(naps).to eq([7.0])
    end

    it "shuts the vendor for its other models too" do
      other = instance_double(LLM::Evals::Model, name: "anthropic/other", provider: provider)
      failed = false
      throttle.call(model) { failed ? :reply : (failed = true; raise IOError) }
      naps.clear
      clock[0] -= 3
      throttle.call(other) { :reply }
      expect(naps).to eq([3.0])
    end
  end

  context "when the provider asks for too long" do
    before { allow(provider).to receive(:retry_after).and_return(described_class::MAX_PAUSE + 1) }

    it "gives up" do
      expect { throttle.call(model) { raise IOError } }.to raise_error(IOError)
      expect(naps).to be_empty
    end
  end

  describe ".measure" do
    it "reports what this thread waited, and not the call's own time" do
      allow(provider).to receive(:retry_after).and_return(5)
      attempts = 0
      value, waited = described_class.measure do
        throttle.call(model) do
          now.call(100)
          (attempts += 1) == 1 ? raise(IOError) : :reply
        end
      end
      expect([value, waited]).to eq([:reply, 5.0])
    end
  end

  describe LLM::Evals::Throttle::Limit do
    subject(:bounded) { described_class.new(burst: 2, per_minute: 60) }

    let(:queue) { instance_double(Limiter::RateQueue, shift: nil) }

    before { allow(Limiter::RateQueue).to receive(:new).with(60, interval: 60, balanced: true).and_return(queue) }

    it "lets the burst through, then takes turns" do
      3.times { bounded.acquire }
      expect(queue).to have_received(:shift).once
    end
  end
end
