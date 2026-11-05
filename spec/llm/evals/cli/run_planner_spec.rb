# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::RunPlanner do
  subject(:planner) { described_class.new(configuration:, config:, options:, trackers:) }

  let(:configuration) { LLM::Evals.configuration }
  let(:config) { configuration.lineup }
  let(:options) { {} }
  let(:trackers) { instance_double(LLM::Evals::CLI::TrackerResolver, for_experiment: []) }

  describe "#datasets" do
    it "means every dataset when none is named" do
      expect(planner.datasets([])).to eq(configuration.discovery.datasets)
    end

    it "splits on commas and drops repeats" do
      expect(planner.datasets(["colors,colors"])).to eq(["colors"])
    end

    it "refuses a suite with no datasets" do
      discovery = instance_double(LLM::Evals::Datasets::Discovery, datasets: [], root: "evals")
      empty = instance_double(LLM::Evals::Runtime::Configuration, discovery:)
      expect { described_class.new(configuration: empty, config:, options:, trackers:).datasets([]) }
        .to raise_error(LLM::Evals::Error, "no datasets under evals")
    end
  end

  describe "#experiments" do
    let(:options) { { case: ["clear"] } }
    let(:contender) { LLM::Evals::Models::Contender.new(model: "fake/echo") }

    it "makes one per dataset and contender, of the selected cases" do
      runs = planner.experiments(["colors"], [contender, contender])
      expect(runs.map(&:dataset)).to eq(%w[colors colors])
      expect(runs.first.cases.map(&:id)).to all(start_with("clear"))
    end

    context "with an adapter that keeps what prepare loads" do
      let(:config) { LLM::Evals.configuration.lineup }
      let(:prepared) { Thread::Queue.new }
      let(:release) { Thread::Queue.new }
      # The README's adapter: prepare keeps the dataset's schema for call and
      # context. Each call waits until every experiment has prepared, which is
      # how experiments overlap under -j.
      let(:adapter_class) do
        prepared = self.prepared
        release = self.release
        Class.new(LLM::Evals::Testing::EchoAdapter) do
          define_method(:prepare) do |dataset|
            @schema = "schema-#{dataset}"
            prepared << dataset
          end
          define_method(:call) do |kase, model:|
            release << release.pop
            super(kase, model:).with(metadata: { schema: @schema, context: context(kase)[:schema] })
          end
          define_method(:context) { |_kase| { schema: @schema } }
        end
      end

      def run_together(runs)
        Thread.new { runs.size.times { prepared.pop } && (release << :go) }
        Timeout.timeout(5) { runs.map { |run| Thread.new { run.run } }.map(&:value) }
      ensure
        release << :go
      end

      def schemas_seen(summaries)
        summaries.to_h { |summary| [summary.dataset, summary.results.flat_map { it.reply.metadata.values_at(:schema, :context) }.uniq] }
      end

      shared_examples "an adapter per experiment" do
        it "gives each experiment its own adapter" do
          runs = planner.experiments(%w[animals colors], [contender, contender])
          expect(runs.map(&:adapter).uniq.size).to eq(4)
        end

        it "keeps each dataset's schema in its own experiment when two run at once" do
          summaries = run_together(planner.experiments(%w[animals colors], [contender]))
          expect(schemas_seen(summaries)).to eq("animals" => ["schema-animals"], "colors" => ["schema-colors"])
        end

        context "with cases in parallel" do
          let(:options) { { parallelism: "2" } }

          it "shares the experiment's adapter across its cases" do
            summaries = run_together(planner.experiments(%w[animals colors], [contender]))
            expect(schemas_seen(summaries)).to eq("animals" => ["schema-animals"], "colors" => ["schema-colors"])
          end
        end
      end

      context "when the helper registers its class" do
        let(:configuration) do
          configuration_for(File.join(TOY_SUITE, "evals")).tap do |c|
            c.adapter adapter_class
            c.provider LLM::Evals::Testing::FakeProvider.new
          end
        end

        it_behaves_like "an adapter per experiment"
      end

      context "when the config file names it" do
        let(:root) { copy_toy_suite }
        let(:configuration) do
          LLM::Evals::Runtime::Configuration.new.tap do |c|
            c.suite "config-only", root: root
            c.provider LLM::Evals::Testing::FakeProvider.new
            c.require_suite!
          end
        end

        before do
          stub_const("SchemaAdapter", adapter_class)
          File.write(File.join(root, ".llm-evals.config.yml"), "adapter: SchemaAdapter\nscorer: ToySuite::Evals::Scorer\n")
        end

        after { FileUtils.remove_entry(File.dirname(root)) }

        it_behaves_like "an adapter per experiment"
      end
    end

    context "with an adapter instance" do
      it "shares it, as registered" do
        runs = planner.experiments(%w[animals colors], [contender])
        expect(runs.map(&:adapter)).to all(be(configuration.adapter))
      end
    end
  end

  describe "#parallelism" do
    it { expect(planner.parallelism).to eq(Integer(config.defaults["parallelism"])) }

    context "with the flag" do
      let(:options) { { parallelism: "7" } }

      it { expect(planner.parallelism).to eq(7) }
    end
  end

  describe "#concurrency" do
    it { expect(planner.concurrency).to eq(Etc.nprocessors) }

    {
      "3" => 3,
      "0" => 0
    }.each do |flag, expected|
      it "reads -j #{flag}" do
        expect(described_class.new(configuration:, config:, options: { concurrency: flag }, trackers:).concurrency).to eq(expected)
      end
    end

    it "refuses a negative -j" do
      expect { described_class.new(configuration:, config:, options: { concurrency: "-1" }, trackers:).concurrency }
        .to raise_error(LLM::Evals::Error, "--concurrency must be 0 or more, got -1")
    end

    it "refuses a -j that is no number" do
      expect { described_class.new(configuration:, config:, options: { concurrency: "many" }, trackers:).concurrency }
        .to raise_error(LLM::Evals::Error, '--concurrency must be a whole number, got "many"')
    end
  end
end
