# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::ReportDispatcher do
  let(:pipeline_class) { LLM::Evals::Render::Reports::Pipeline }
  let(:pipeline) { instance_double(pipeline_class, save_json: "/d/saved.json", write_json: "{json}", write_html: "<html>", report_path: "/log/p.report.html") }
  let(:console) { instance_double(LLM::Evals::CLI::ReportDispatcher::Console, written: nil, could_not_open: nil, browse: true, print: nil, save_warnings: nil) }
  let(:invocation) { instance_double(Dry::CLI::UI::Invocation, report_path: "/log/x.log") }
  let(:results) { { autosave: true, display: "tui", destination: "/d", temp_dir: "/t" } }

  def snapshot(output: nil, open: false, results: self.results)
    LLM::Evals::CLI::ReportDispatcher::Snapshot.new(summaries: [], metrics: [], weighted_score: nil, run_options: {}, results:, output:, open:)
  end

  def output(klass) = klass.new(pipeline:, console:, invocation:)

  describe described_class::HtmlOutput do
    subject(:html) { output(described_class) }

    before { allow(File).to receive(:read).and_call_original }

    context "with autosave" do
      before { allow(File).to receive(:read).with("/d/saved.json").and_return("{saved}") }

      it "renders from the saved JSON, and says where it is" do
        html.write(snapshot)
        expect(pipeline).to have_received(:write_html).with(json: "{saved}", path: "/log/p.report.html")
        expect(console).to have_received(:written).with("JSON results", "/d/saved.json")
      end
    end

    context "without autosave" do
      let(:results) { { autosave: false } }

      it "renders from JSON it does not keep" do
        html.write(snapshot)
        expect(pipeline).to have_received(:write_html).with(json: "{json}", path: "/log/p.report.html")
        expect(pipeline).not_to have_received(:save_json)
      end

      it "prints the page for -o -, and opens nothing" do
        html.write(snapshot(output: "-", open: true))
        expect(console).to have_received(:print).with("<html>")
        expect(console).not_to have_received(:browse)
      end

      it "names the page after -o, with its own extension" do
        html.write(snapshot(output: "x"))
        expect(pipeline).to have_received(:write_html).with(json: "{json}", path: "/log/x.html")
      end

      it "opens a written page, escaped" do
        allow(pipeline).to receive(:report_path).and_return("/log/a b.html")
        html.write(snapshot(open: true))
        expect(console).to have_received(:browse).with("file:///log/a%20b.html")
        expect(console).not_to have_received(:could_not_open)
      end

      it "warns when the browser would not open" do
        allow(console).to receive(:browse).and_return(false)
        html.write(snapshot(open: true))
        expect(console).to have_received(:could_not_open).with("/log/p.report.html")
      end

      it "saves the warnings" do
        html.write(snapshot)
        expect(console).to have_received(:save_warnings)
      end
    end
  end

  describe described_class::JsonOutput do
    subject(:json) { output(described_class) }

    it "saves beside the others when -o names nothing" do
      [nil, ""].each { json.write(snapshot(output: it)) }
      expect(console).to have_received(:written).with("JSON report", "/d/saved.json").twice
    end

    it "prints for -o -" do
      json.write(snapshot(output: "-"))
      expect(pipeline).to have_received(:write_json).with(hash_including(path: nil))
      expect(console).to have_received(:print).with("{json}")
    end

    it "writes where -o says, with its own extension" do
      json.write(snapshot(output: "x"))
      expect(pipeline).to have_received(:write_json).with(hash_including(path: "/log/x.json"))
      expect(console).to have_received(:written).with("JSON report", "/log/x.json")
    end

    it "saves the warnings" do
      json.write(snapshot)
      expect(console).to have_received(:save_warnings)
    end
  end

  describe described_class::PipelineOutput do
    subject(:configured) { output(described_class) }

    let(:result) { pipeline_class::Result.new(json_path: nil, html_path: nil, css_path: nil, js_path: nil, browser_opened: nil) }

    before { allow(pipeline).to receive(:call).and_return(result) }

    it "hands the terminal view to the pipeline, which has it say so about warnings" do
      allow(pipeline).to receive(:call).and_yield(:report).and_return(result)
      shown = []
      configured.write(snapshot) { shown << it }
      expect(shown).to eq([:report])
      expect(console).not_to have_received(:save_warnings)
    end

    context "with a page and a saved snapshot" do
      let(:results) { { autosave: true, display: "browser" } }
      let(:result) { pipeline_class::Result.new(json_path: "/d/a.json", html_path: "/d/a.html", css_path: nil, js_path: nil, browser_opened: false) }

      it "says where each went, and saves the warnings" do
        configured.write(snapshot)
        expect(console).to have_received(:written).with("JSON results", "/d/a.json")
        expect(console).to have_received(:written).with("HTML report", "/d/a.html")
        expect(console).to have_received(:save_warnings)
      end

      it "warns about a page that would not open, only if asked to open it" do
        configured.write(snapshot)
        expect(console).not_to have_received(:could_not_open)
        configured.write(snapshot(open: true))
        expect(console).to have_received(:could_not_open).with("/d/a.html")
      end
    end
  end

  describe "#call" do
    subject(:dispatcher) do
      described_class.new(config:, options:, providers: nil, runtime: nil, suite: "suite", console:, invocation:)
    end

    let(:config) do
      results = LLM::Evals::Config::Results.new(autosave: true, destination: "/d", temp_dir: "/t", display_mode: "browser")
      instance_double(LLM::Evals::Config, results:)
    end
    let(:options) { {} }
    let(:written) { [] }

    before do
      [described_class::HtmlOutput, described_class::JsonOutput, described_class::PipelineOutput].each do |klass|
        allow(klass).to receive(:new) do
          strategy = instance_double(klass)
          allow(strategy).to receive(:write) { |snapshot| written << [klass, snapshot] }
          strategy
        end
      end
    end

    def dispatch(format: nil, run_options: {})
      dispatcher.call([], metrics: [], weighted_score: nil, run_options:, output: nil, open: false, format:)
      written.last
    end

    {
      "html" => [:HtmlOutput, "browser"],
      "json" => [:JsonOutput, "none"],
      "tui"  => [:PipelineOutput, "tui"]
    }.each do |format, (strategy, display)|
      it "sends #{format} to #{strategy}, displaying #{display}" do
        klass, snapshot = dispatch(format:)
        expect(klass).to eq(described_class.const_get(strategy))
        expect(snapshot.results[:display]).to eq(display)
      end
    end

    it "uses the lineup's display with no format" do
      klass, snapshot = dispatch
      expect(klass).to eq(described_class::PipelineOutput)
      expect(snapshot.results).to include(autosave: true, destination: "/d", temp_dir: "/t", display: "browser")
    end

    it "records the results it settled on in the run options" do
      expect(dispatch(run_options: { a: 1 }).last.run_options).to include(a: 1, results: hash_including(display: "browser"))
    end

    context "with flags over the lineup" do
      let(:options) { { autosave: false, destination: "/flag", temp_dir: "/tmp-flag", display: "none" } }

      it { expect(dispatch.last.results).to include(autosave: false, destination: "/flag", temp_dir: "/tmp-flag", display: "none") }
    end

    context "when naming the pipeline's files" do
      before { allow(pipeline_class).to receive(:new).and_call_original }

      it "prefers the run's project, then the suite" do
        dispatch(run_options: { effective: { project: "p" } })
        dispatch(run_options: { "effective" => { "project" => "q" } })
        dispatch
        %w[p q suite].each { |project| expect(pipeline_class).to have_received(:new).with(hash_including(project:)) }
      end
    end
  end
end
