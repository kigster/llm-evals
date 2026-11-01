# frozen_string_literal: true

RSpec.describe LLM::Evals::Providers::TypeSafe do
  subject(:provider) { described_class.new }

  describe "#ask" do
    let(:model) { LLM::Evals::Model.new(id: "typesafe/jev-1.14.0", provider: provider, settings: {}) }
    let(:questions) { { "paid" => { type: "noul", instructions: "Was it paid?" } } }

    def reply(klass, code, body, headers = {})
      klass.new("1.1", code, "").tap do |response|
        headers.each { |key, value| response[key] = value }
        allow(response).to receive(:body).and_return(body)
      end
    end

    it "sends the model's own name, and returns the answers with the cost" do
      answer = reply(Net::HTTPOK, "200", '{"answers":{"paid":{"type":"noul","noul":0.9}},"usage":{"input_tokens":1000000,"output_tokens":3}}')
      http = instance_double(Net::HTTP, request: answer)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      completion = model.ask(state: "text", questions: questions)
      expect(http).to have_received(:request).with(have_attributes(body: JSON.generate({ model: "jev-1.14.0", state: "text", questions: questions })))
      expect(completion.raw.dig("paid", "noul")).to eq(0.9)
      expect(completion.usage.cost_usd).to be_within(1e-9).of(0.042)
    end

    it "raises the status and Retry-After of a refusal" do
      allow(Net::HTTP).to receive(:start).and_return(reply(Net::HTTPUnprocessableEntity, "422", "bad field", "retry-after" => "3"))
      expect { provider.ask(model, state: "text", questions: questions) }
        .to raise_error(described_class::HTTPError) { |e| expect([e.status, e.retry_after, e.message]).to eq([422, 3.0, "TypeSafe answered 422: bad field"]) }
    end

    it "retries rate limits, overloads and dropped connections, not a bad request" do
      limited = described_class::HTTPError.new(reply(Net::HTTPTooManyRequests, "429", ""))
      overloaded = described_class::HTTPError.new(reply(Net::HTTPInternalServerError, "529", ""))
      invalid = described_class::HTTPError.new(reply(Net::HTTPUnprocessableEntity, "422", ""))
      expect([limited, overloaded, Net::ReadTimeout.new, invalid, IOError.new].map { provider.retryable?(it) }).to eq([true, true, true, false, false])
    end

    it "builds a bearer request" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) { |request| expect(request["Content-Type"]).to eq("application/json") and reply(Net::HTTPOK, "200", '{"answers":{}}') }
      expect(provider.ask(model, state: "s", questions: questions).raw).to eq({})
    end
  end

  its(:name) { is_expected.to eq("typesafe") }
  its(:request_type) { is_expected.to eq(:typesafe) }
  its(:efforts) { is_expected.to eq([]) }
  its(:env_keys) { is_expected.to eq(["TYPESAFE_API_KEY"]) }
  it { is_expected.to be_direct }
  its(:request_type_description) { is_expected.to eq("typed questions: noul, choice, score") }
  it { expect(provider.model_name("typesafe/jev-latest")).to eq("jev-latest") }
  it { expect(provider.usage(input_tokens: 1_000_000).cost_usd).to be_within(1e-9).of(0.042) }

  it "lists the catalog with the prefix" do
    allow(LLM::Evals::Providers::Catalog).to receive(:fetch).with(described_class::URL, hash_including("Authorization"))
                                                            .and_return("models" => [{ "name" => "jev-latest" }])
    expect(provider.catalog).to eq(["typesafe/jev-latest"])
  end

  it "refuses to chat" do
    model = provider.model_for(LLM::Evals::Contender.new(model: "typesafe/jev-latest", provider: :typesafe))
    expect { model.complete(user: "x") }.to raise_error(LLM::Evals::Error, /answers typed questions, not prompts/)
  end
end
