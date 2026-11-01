# frozen_string_literal: true

RSpec.describe LLM::Evals::Providers::OpenRouter do
  subject(:provider) { described_class.new }

  let(:reply) { "```json\n{\"a\": 1}\n```" }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:model) { LLM::Evals::Model.new(id: "acme/m1", provider: provider, settings: { effort: "low", temperature: 0.0, max_tokens: 500 }) }

  before do
    require "ruby_llm"
    allow(RubyLLM).to receive(:chat).and_return(chat)
    %i[with_instructions with_temperature with_max_output_tokens with_thinking with_provider_options].each do |name|
      allow(chat).to receive(name).and_return(chat)
    end
    tokens = RubyLLM::Tokens.new(input: 1200, output: 80, reported_cost: 0.0003)
    allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: reply, tokens: tokens))
  end

  describe "#setup!" do
    it "turns RubyLLM's retries off" do
      described_class.new.setup!(app_name: "t")
      expect(RubyLLM.config.max_retries).to eq(0)
    end
  end

  describe "#retryable?" do
    subject(:provider) { described_class.new }

    before { LLM::Evals.optional!("ruby_llm", needed_for: "this spec") }

    it("retries a rate limit") { expect(provider.retryable?(RubyLLM::RateLimitError.new("slow"))).to be(true) }
    it("retries a server error") { expect(provider.retryable?(RubyLLM::ServerError.new("oops"))).to be(true) }
    it("retries a dropped connection") { expect(provider.retryable?(Faraday::ConnectionFailed.new("gone"))).to be(true) }
    it("does not retry an empty account") { expect(provider.retryable?(RubyLLM::PaymentRequiredError.new("pay"))).to be(false) }
  end

  describe "#retry_after" do
    subject(:provider) { described_class.new }

    before { LLM::Evals.optional!("ruby_llm", needed_for: "this spec") }

    def limited(headers) = RubyLLM::RateLimitError.new("slow", response: Faraday::Env.from(response_headers: Faraday::Utils::Headers.new(headers), body: "slow"))

    it("reads the header") { expect(provider.retry_after(limited("retry-after" => "7"))).to eq(7.0) }
    it("is nil without it") { expect(provider.retry_after(limited({}))).to be_nil }
    it("is nil for an error with no response") { expect(provider.retry_after(IOError.new)).to be_nil }
  end

  its(:name) { is_expected.to eq("openrouter") }
  its(:request_type) { is_expected.to eq(:prompt) }
  its(:request_type_description) { is_expected.to include("chat completion") }
  it { is_expected.not_to be_direct }
  it("serves Jev on OpenRouter as a chat model") { expect(provider).to be_serves("typesafe/jev-router") }
  its(:env_keys) { is_expected.to eq(["OPENROUTER_API_KEY"]) }
  its(:prefix) { is_expected.to eq("") }
  it { expect(provider.model_name("acme/m1")).to eq("acme/m1") }

  it "lists the catalog" do
    allow(LLM::Evals::Providers::Catalog).to receive(:fetch).with(described_class::URL).and_return("data" => [{ "id" => "a/b" }])
    expect(provider.catalog).to eq(["a/b"])
  end

  it "configures RubyLLM for OpenRouter" do
    ENV["OPENROUTER_API_KEY"] = "k"
    provider.setup!(app_name: "spec suite")
    expect(RubyLLM.config).to have_attributes(openrouter_api_key: "k", openrouter_app_name: "spec suite")
  ensure
    ENV.delete("OPENROUTER_API_KEY")
  end

  describe "#complete" do
    subject(:completion) { model.complete(system: "sys", user: "hello") }

    its(:text) { is_expected.to eq(reply) }
    it { expect(completion.usage).to eq(LLM::Evals::Usage.new(input_tokens: 1200, output_tokens: 80, cost_usd: 0.0003)) }

    it "sends the prompts through OpenRouter" do
      completion
      expect(RubyLLM).to have_received(:chat).with(model: "acme/m1", provider: :openrouter, assume_model_exists: true)
      expect(chat).to have_received(:with_instructions).with("sys")
      expect(chat).to have_received(:ask).with("hello")
    end

    it "sends the settings" do
      completion
      expect(chat).to have_received(:with_thinking).with(effort: :low)
      expect(chat).to have_received(:with_temperature).with(0.0)
      expect(chat).to have_received(:with_max_output_tokens).with(500)
      expect(chat).to have_received(:with_provider_options).with(response_format: { type: "json_object" })
    end

    context "with the model's own defaults and no JSON mode" do
      let(:model) { LLM::Evals::Model.new(id: "acme/m1", provider: provider) }

      before { model.complete(user: "hello", json: false) }

      it { expect(chat).not_to have_received(:with_thinking) }
      it { expect(chat).not_to have_received(:with_temperature) }
      it { expect(chat).not_to have_received(:with_max_output_tokens) }
      it { expect(chat).not_to have_received(:with_instructions) }
      it { expect(chat).not_to have_received(:with_provider_options) }
    end
  end
end
