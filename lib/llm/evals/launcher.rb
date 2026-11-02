# frozen_string_literal: true

module LLM
  module Evals
    # Starts the CLI. The executable and the specs both build one, each with
    # its own argv and streams, and it exits only through kernel.exit.
    class Launcher
      # @param argv [Array<String>] the arguments, which may hold `--helper` for {Runtime::Helper}
      # @param stdin [IO] nothing reads it yet
      # @param stdout [IO]
      # @param stderr [IO]
      # @param kernel [#exit] replaced in the specs, so a test run survives the exit
      def initialize(argv, stdin = $stdin, stdout = $stdout, stderr = $stderr, kernel = Kernel)
        @argv = argv
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
        @kernel = kernel
      end

      # Runs the command, and exits with its status.
      #
      # @return [void]
      def execute!
        @kernel.exit(run)
      end

      private

      # dry-cli exits by itself after help or a usage error; its status is kept.
      # @return [Integer] the exit status: the command's own, or 1 on an error, which prints
      #   as one line unless -v asked for its backtrace
      def run
        argv, helper = Runtime::Helper.extract(@argv)
        Runtime::Helper.load!(Runtime::Helper.locate(helper))
        Dry::CLI.new(CLI).call(arguments: argv, out: @stdout, err: @stderr)
        0
      rescue SystemExit => e
        e.status
      rescue StandardError => e
        @stderr.puts "error: #{e.message}"
        @stderr.puts(e.backtrace) if @argv.intersect?(%w[-v --verbose])
        1
      end
    end
  end
end
