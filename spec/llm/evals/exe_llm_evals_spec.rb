# frozen_string_literal: true

require "pty"
require "timeout"

# The executable's one-time welcome, in a fresh process under a throwaway home,
# so that the semaphore file on the machine running the suite is left alone.
RSpec.describe "exe/llm-evals" do
  let(:exe) { File.expand_path("../../../exe/llm-evals", __dir__) }
  let(:home) { File.realpath(Dir.mktmpdir) }
  let(:semaphore) { File.join(home, ".local", "share", "llm-evals", "warning-semaphore.yml") }

  after { FileUtils.remove_entry(home) }

  def run_exe(*) = Open3.capture3({ "HOME" => home }, RbConfig.ruby, exe, *, chdir: home)

  context "when run for the first time" do
    subject(:run) { run_exe("version") }

    it "welcomes on stderr, keeping stdout for the command" do
      stdout, stderr, status = run
      expect(status.exitstatus).to eq(0), stderr
      expect(stderr).to include("Welcome to the llm-evals CLI!", "This message won't be shown again")
      expect(stdout).to eq("#{LLM::Evals::VERSION}\n")
    end

    it "records the date in the semaphore file" do
      run
      expect(YAML.safe_load_file(semaphore)).to include("warning_shown_on" => a_string_matching(/\A\d{4}-\d{2}-\d{2}T/))
    end

    it "welcomes even with warnings silenced, since it only ever shows once" do
      _stdout, stderr, = Open3.capture3({ "HOME" => home, "RUBYOPT" => "#{ENV.fetch("RUBYOPT", "")} -W0" }, RbConfig.ruby, exe, "version", chdir: home)
      expect(stderr).to include("Welcome to the llm-evals CLI!")
    end

    it "does not wait for a key without a terminal" do
      expect(Timeout.timeout(15) { run }.last).to be_success
    end
  end

  context "when run again" do
    before { run_exe("version") }

    it "does not welcome twice" do
      stdout, stderr, status = run_exe("version")
      expect(status.exitstatus).to eq(0), stderr
      expect(stderr).not_to include("Welcome")
      expect(stdout).to eq("#{LLM::Evals::VERSION}\n")
    end

    it "leaves the semaphore file as it was" do
      expect { run_exe("version") }.not_to(change { File.read(semaphore) })
    end
  end

  context "with an empty semaphore file" do
    before do
      FileUtils.mkdir_p(File.dirname(semaphore))
      FileUtils.touch(semaphore)
    end

    it "welcomes, and writes the file" do
      _stdout, stderr, = run_exe("version")
      expect(stderr).to include("Welcome")
      expect(YAML.safe_load_file(semaphore)).to have_key("warning_shown_on")
    end
  end

  context "with a terminal" do
    it "continues on a key press, and runs the command" do
      output = +""
      PTY.spawn({ "HOME" => home }, RbConfig.ruby, exe, "version", chdir: home) do |reader, writer, pid|
        Timeout.timeout(15) do
          output << reader.readpartial(4096) until output.include?("Press any key")
          writer.write("x")
          begin
            loop { output << reader.readpartial(4096) }
          rescue EOFError, Errno::EIO
            Process.wait(pid)
          end
        end
      end
      expect(output).to include(LLM::Evals::VERSION)
      expect(output).not_to include("No key pressed")
      expect($CHILD_STATUS).to be_success
    end
  end
end
