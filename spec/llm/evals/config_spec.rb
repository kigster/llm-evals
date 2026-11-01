# frozen_string_literal: true

RSpec.describe LLM::Evals::Config do
  subject(:config) { described_class.new(path) }

  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "config.yml") }

  after { FileUtils.remove_entry(dir) }

  context "with vendors, defaults and lists" do
    before do
      File.write(path, <<~YAML)
        project: p1
        defaults:
          temperature: 0.5
        openrouter:
          vendors:
            acme:
              models:
                - model: big
                  effort: [low, high]
                  temperature: [0.0, 1.0]
                - model: small
            typesafe:
              models:
                - model: jev-router
        typesafe:
          models:
            - model: jev-latest
              temperature: [0.5, 0.9]
      YAML
    end

    it "keeps the file's order, with direct entries carrying their provider" do
      expect(config.contenders.map { [it.model, it.provider, it.temperature] }.last(3)).to eq(
        [["typesafe/jev-router", nil, 0.5], ["typesafe/jev-latest", :typesafe, 0.5], ["typesafe/jev-latest", :typesafe, 0.9]]
      )
    end

    it "keeps a vendors id and a direct id apart by key" do
      expect(config.contenders.map(&:key).last(2)).to eq(%w[typesafe:typesafe/jev-latest typesafe:typesafe/jev-latest])
      expect(config.contenders[-3]).not_to be_direct
    end

    it "refuses an unknown provider, naming the file" do
      File.write(path, "ollama:\n  models:\n    - llama3\n")
      expect { config.contenders }.to raise_error(LLM::Evals::Error, /#{Regexp.escape(path)}: unknown provider "ollama"; known: /)
    end

    its(:project) { is_expected.to eq("p1") }
    its(:defaults) { is_expected.to include("temperature" => 0.5, "effort" => "default", "max_tokens" => 4096) }

    it "expands every effort and temperature" do
      expect(config.contenders.first(5).map { [it.model, it.effort, it.temperature] }).to eq(
        [["acme/big", "low", 0.0], ["acme/big", "low", 1.0], ["acme/big", "high", 0.0], ["acme/big", "high", 1.0],
         ["acme/small", "default", 0.5]]
      )
    end

    it "lets flags beat the file" do
      expect(config.contenders("effort" => "max", "temperature" => nil).map(&:effort).uniq).to eq(["max"])
    end

    it "builds contenders for models given directly" do
      expect(config.contenders_for(["x/y"], "max_tokens" => "100").first).to have_attributes(model: "x/y", max_tokens: 100)
    end
  end

  context "with the retired keys" do
    before { File.write(path, "vendors:\n  acme:\n    - model: big\n") }

    it { expect { config.contenders }.to raise_error(LLM::Evals::Error, /vendors no longer exist/) }
  end

  context "with a bare model name" do
    before { File.write(path, "typesafe:\n  models:\n    - jev-1.14.0\n") }

    it { expect(config.contenders.first).to have_attributes(model: "typesafe/jev-1.14.0", provider: :typesafe) }
  end

  context "with a misspelled key on an entry" do
    before { File.write(path, "typesafe:\n  models:\n    - model: jev\n      ratelimit: 1\n") }

    it { expect { config.contenders }.to raise_error(LLM::Evals::Error, /unknown keys under jev: ratelimit/) }
  end

  describe "#throttle" do
    before do
      File.write(path, <<~YAML)
        openrouter:
          rate_limit: { burst: 1000, per_minute: 500 }
          vendors:
            anthropic:
              rate_limit: { burst: 10, per_minute: 50 }
              models:
                - model: claude-opus-5
                - model: claude-fable-5
                  rate_limit: { burst: 5, per_minute: 20 }
            openai:
              models:
                - model: gpt-6.1-sol
        typesafe:
          models:
            - jev-1.14.0
      YAML
      allow(LLM::Evals::Throttle).to receive(:new).and_call_original
    end

    it "keys each limit by provider, vendor and model" do
      config.throttle
      expect(LLM::Evals::Throttle).to have_received(:new).with(
        { "openrouter"                          => an_instance_of(LLM::Evals::Throttle::Limit),
          "openrouter/anthropic"                => an_instance_of(LLM::Evals::Throttle::Limit),
          "openrouter/anthropic/claude-fable-5" => an_instance_of(LLM::Evals::Throttle::Limit) }
      )
    end

    it "refuses a limit without both numbers" do
      File.write(path, "openrouter:\n  rate_limit: { burst: 10 }\n  vendors: {}\n")
      expect { config.throttle }.to raise_error(LLM::Evals::Error, /rate_limit of openrouter needs burst and per_minute/)
    end
  end

  context "without a file" do
    its(:contenders) { is_expected.to eq([]) }
    its(:project) { is_expected.to be_nil }
    it { expect { config.request_types }.to raise_error(LLM::Evals::Error, /#{Regexp.escape(path)}: request_types is required; list one or more of prompt, typesafe/) }
  end

  describe "#tracker and #tracker_options" do
    it "reads one tracker and its section" do
      File.write(path, "tracker: logfire\nlogfire:\n  include_replies: true\n")
      expect(config.tracker).to eq("logfire")
      expect(config.tracker_options("logfire")).to eq("include_replies" => true)
      expect(config.tracker_options("braintrust")).to eq({})
    end

    it { expect(config.tracker).to be_nil }

    it "refuses a list of several" do
      File.write(path, "tracker: [braintrust, logfire]\n")
      expect { config.tracker }.to raise_error(LLM::Evals::Error, /#{Regexp.escape(path)}: tracker: names braintrust, logfire; exactly one remote tracker runs, or none/)
    end
  end

  describe "#score_weights" do
    it "is empty without the section" do
      expect(config.score_weights).to eq({})
    end

    it "reads the weights" do
      File.write(path, "weighted_score:\n  weights:\n    cost: -0.5\n")
      expect(config.score_weights).to eq("cost" => -0.5)
    end

    it "refuses a section without a weights mapping" do
      File.write(path, "weighted_score: 3\n")
      expect { config.score_weights }.to raise_error(LLM::Evals::Error, /needs a weights: mapping/)
    end
  end

  describe "#results" do
    it "provides compatible defaults when the results section is absent" do
      expect(config.results).to have_attributes(autosave: true, display_mode: "tui")
      expect(config.results.destination).to eq(File.expand_path("evals/results", Dir.pwd))
      expect(config.results.temp_dir).to eq(File.expand_path("tmp", Dir.pwd))
    end

    it "reads autosave, directories and display from the config" do
      File.write(path, <<~YAML)
        results:
          autosave: true
          destination: ./custom/results
          temp_dir: ./custom/tmp
          display: browser
      YAML

      expect(config.results).to have_attributes(autosave: true, display_mode: "browser")
      expect(config.results.destination).to eq(File.expand_path("custom/results", Dir.pwd))
      expect(config.results.temp_dir).to eq(File.expand_path("custom/tmp", Dir.pwd))
    end

    it "rejects unsupported display modes" do
      File.write(path, "results:\n  display: terminal\n")

      expect { config.results }.to raise_error(LLM::Evals::Error, /display must be one of none, tui, browser/)
    end

    it "requires autosave to be a boolean" do
      File.write(path, "results:\n  autosave: enabled\n")

      expect { config.results }.to raise_error(LLM::Evals::Error, /autosave must be true or false/)
    end
  end

  describe "#request_types" do
    it "reads the declared types as symbols" do
      File.write(path, "request_types: [prompt, typesafe]\n")
      expect(config.request_types).to eq(%i[prompt typesafe])
    end

    it "refuses an empty list, naming the file" do
      File.write(path, "request_types: []\n")
      expect { config.request_types }.to raise_error(LLM::Evals::Error, /#{Regexp.escape(path)}: request_types is required/)
    end

    it "refuses an unknown type, naming the file" do
      File.write(path, "request_types: [prompt, telepathy]\n")
      expect { config.request_types }.to raise_error(LLM::Evals::Error, /#{Regexp.escape(path)}: unknown request_types telepathy; known: prompt, typesafe/)
    end
  end

  context "with the toy suite's lineup" do
    subject(:config) { LLM::Evals.configuration.lineup }

    it { expect(config.contenders.map(&:model)).to eq(%w[fake/echo fake/echo fake/parrot typesafe/jev-latest]) }
    it { expect(config.contenders.last).to be_direct }
    it { expect(config.request_types).to eq([:prompt]) }
  end
end
