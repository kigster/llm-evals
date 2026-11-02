# frozen_string_literal: true

module LLM
  module Evals
    # Starts the CLI. The executable and the specs both build one, each with
    # its own argv and streams, and it exits only through kernel.exit.
    class Launcher
      # Commands whose output is piped or which say nothing about a suite.
      UNANNOUNCED = %w[version -V --version completion].freeze
      # Help prints the box after itself, and everything else before.
      HELP = %w[help -h --help].freeze

      # @param argv [Array<String>] the arguments, which may hold `--helper` and `--no-search` for {Runtime::Helper}
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
        argv, search = Runtime::Helper.extract_search(argv)
        search &&= !Runtime::Helper.config_flag?(argv)
        found = Runtime::Helper.locate(helper, search: search)
        LLM::Evals.configuration.located_from(Dir.pwd, search: search)
        in_home(found) do
          Runtime::Helper.load!(found)
          dispatch(argv)
        end
        0
      rescue SystemExit => e
        e.status
      rescue StandardError => e
        @stderr.puts "error: #{e.message}"
        @stderr.puts(e.backtrace) if @argv.intersect?(%w[-v --verbose])
        1
      end

      # Runs where the search found the suite; the caller's directory comes back afterwards.
      #
      # @param found [Runtime::Helper::Found]
      # @yield the work to run there
      # @return [Object] what the block returned
      def in_home(found, &)
        found.home ? Dir.chdir(found.home, &) : yield
      end

      # Runs the command with the configuration's box first, or after the help.
      #
      # @param argv [Array<String>] the arguments dry-cli will read
      # @return [void]
      def dispatch(argv)
        help = argv.empty? || argv.intersect?(HELP)
        announce(argv) unless help
        Dry::CLI.new(CLI).call(arguments: argv, out: @stdout, err: @stderr)
      ensure
        announce(argv) if help
      end

      # Says on stderr which configuration the run uses, or that there is none.
      #
      # @param argv [Array<String>] the arguments dry-cli will read
      # @return [void]
      def announce(argv)
        return if UNANNOUNCED.include?(argv.first) || Runtime::Helper.config_flag?(argv)

        @stdout.flush
        color = @stderr.tty? && !ENV.key?("NO_COLOR")
        @stderr.print("\n", CLI.dataset_conf_label(configuration: LLM::Evals.configuration, color: color))
      end
    end
  end
end
