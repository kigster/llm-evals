# frozen_string_literal: true

RSpec.describe LLM::Evals::CLI::OptionGroups do
  def help(*command)
    out, err = capture_help(command)
    out + err
  end

  def capture_help(command)
    stdout = StringIO.new
    stderr = StringIO.new
    Dry::CLI.new(LLM::Evals::CLI).call(arguments: [*command, "--help"], out: stdout, err: stderr)
    [stdout.string, stderr.string]
  rescue SystemExit
    [stdout.string, stderr.string]
  end

  it "lists run's flags under their groups, in order" do
    text = help("run")
    expect(text.index("GENERAL OPTIONS")).to be < text.index("TUI OPTIONS")
    expect(text.index("TUI OPTIONS")).to be < text.index("BROWSER REPORT OPTIONS")
    expect(text).not_to match(/^OPTIONS/)
  end

  it "puts each flag in its group" do
    text = help("compare")
    general, rest = text.split("TUI OPTIONS")
    tui, browser = rest.split("BROWSER REPORT OPTIONS")
    expect(general).to include("--models", "--display", "--help")
    expect(tui).to include("--[no-]scores", "--totals")
    expect(browser).to include("--[no-]open")
  end

  it "leaves a command with no groups alone" do
    expect(help("cases")).not_to include("GENERAL OPTIONS")
  end
end
