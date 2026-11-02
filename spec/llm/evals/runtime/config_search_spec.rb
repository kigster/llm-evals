# frozen_string_literal: true

RSpec.describe "searching for the configuration file" do
  let(:dir) { File.realpath(Dir.mktmpdir) }
  let(:configuration) { LLM::Evals::Runtime::Configuration.new }
  let(:helper) { LLM::Evals::Runtime::Helper }
  let(:file) { LLM::Evals::Runtime::Configuration::DEFAULT_CONFIG }

  after { FileUtils.remove_entry(dir) }

  def place(*segments)
    path = File.join(dir, *segments, file)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)
    path
  end

  describe "Configuration.search_config_file" do
    subject(:search) { LLM::Evals::Runtime::Configuration.search_config_file(from: dir) }

    it { is_expected.to be_nil }

    it "finds a file four directories down" do
      path = place("a", "b", "c", "evals")
      expect(search).to eq(path)
    end

    it "stops at four directories" do
      place("a", "b", "c", "d", "evals")
      expect(search).to be_nil
    end

    it "prefers the shallowest, then the first by name" do
      place("a", "b", "c")
      place("z", "evals")
      winner = place("m", "evals")
      expect(search).to eq(winner)
    end

    it "does not enter hidden or vendored directories" do
      place(".claude", "evals")
      place("node_modules", "evals")
      place("vendor", "evals")
      expect(search).to be_nil
    end
  end

  describe "Helper.locate" do
    it "searches only when asked" do
      place("a", "evals")
      expect(helper.locate(nil, from: dir, env: {})).not_to be_any
    end

    it "runs a file inside evals/ from the directory above it" do
      path = place("a", "b", "evals")
      found = helper.locate(nil, from: dir, env: {}, search: true)
      expect(found).to have_attributes(config: path, helper: nil, home: File.join(dir, "a", "b"))
    end

    it "runs any other file from its own directory" do
      place("a", "b")
      expect(helper.locate(nil, from: dir, env: {}, search: true).home).to eq(File.join(dir, "a", "b"))
    end

    it "picks up the helper beside the file" do
      place("a", "evals")
      path = File.join(dir, "a", "evals", "eval_helper.rb")
      FileUtils.touch(path)
      expect(helper.locate(nil, from: dir, env: {}, search: true).helper).to eq(path)
    end

    it "does not set a home for what the upward search finds" do
      place("evals")
      expect(helper.locate(nil, from: dir, env: {}, search: true).home).to be_nil
    end
  end

  describe "Helper.extract_search" do
    it { expect(helper.extract_search(%w[run --no-search -v])).to eq([%w[run -v], false]) }
    it { expect(helper.extract_search(%w[run])).to eq([%w[run], true]) }
  end

  describe "Helper.config_flag?" do
    it { expect(helper.config_flag?(%w[run -C x.yml])).to be(true) }
    it { expect(helper.config_flag?(%w[run --config=x.yml])).to be(true) }
    it { expect(helper.config_flag?(%w[run])).to be(false) }
  end

  describe "the box" do
    subject(:box) { LLM::Evals::CLI.dataset_conf_label(configuration:, width: 200) }

    before { configuration.suite("a", root: dir) }

    it "names the suite and the path relative to where the command started" do
      path = place("a", "evals")
      configuration.suite("a", root: File.dirname(path))
      configuration.located_from(dir, search: true)
      expect(box).to include("Info", "Evals configuration: a", "File: a/evals/#{file}")
      expect(box).not_to include(dir)
    end

    it "warns that the file was not found, and that the search failed" do
      configuration.located_from(dir, search: true)
      expect(box).to include("Warning", "was not found", "search 4 directories down failed too")
    end

    it "leaves the search out when it did not run" do
      configuration.located_from(dir, search: false)
      expect(box).to include("was not found")
      expect(box).not_to include("search")
    end

    it "paints a found file on green and a missing one on yellow" do
      expect(LLM::Evals::CLI.dataset_conf_label(configuration:, color: true)).to match(/\e\[[\d;]*43m/)
      place
      expect(LLM::Evals::CLI.dataset_conf_label(configuration:, color: true)).to match(/\e\[[\d;]*42m/)
    end
  end

  describe "the launcher" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:kernel) { class_double(Kernel, exit: nil) }

    before { allow(LLM::Evals).to receive(:configuration).and_return(configuration) }

    def launch(*argv) = LLM::Evals::Launcher.new(argv, StringIO.new, stdout, stderr, kernel).execute!

    it "runs in the project it found and returns to where it started" do
      place("project", "evals")
      seen = nil
      allow(Dry::CLI).to receive(:new).and_return(instance_double(Dry::CLI).tap { |cli| allow(cli).to receive(:call) { seen = Dir.pwd } })
      Dir.chdir(dir) do
        launch("cases")
        expect(Dir.pwd).to eq(dir)
      end
      expect(seen).to eq(File.join(dir, "project"))
    end

    it "does not search with --no-search" do
      place("project", "evals")
      allow(Dry::CLI).to receive(:new).and_return(instance_double(Dry::CLI, call: nil))
      Dir.chdir(dir) { expect(LLM::Evals::Runtime::Helper.locate(nil, env: {}, search: false)).not_to be_any }
      Dir.chdir(dir) { launch("cases", "--no-search") }
      expect(stderr.string).not_to include("search")
    end

    it "prints the box first when running, naming the file relative to the start" do
      place("project", "evals")
      order = []
      allow(Dry::CLI).to receive(:new).and_return(instance_double(Dry::CLI).tap { |cli| allow(cli).to receive(:call) { order << stderr.string.dup } })
      Dir.chdir(dir) { launch("cases") }
      expect(order.first).to include("project/evals/#{file}")
    end

    it "prints the box after the help" do
      configuration.suite("a", root: dir)
      Dir.chdir(dir) { launch("--help") }
      expect(stderr.string).to include("Warning", "was not found")
      expect(stdout.string).to include("compare")
    end

    it "keeps version output free of the box" do
      Dir.chdir(dir) { launch("version") }
      expect(stderr.string).to be_empty
    end
  end
end
