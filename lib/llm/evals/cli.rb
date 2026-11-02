module LLM
  module Evals
    # Every command the executable answers to. The help's title and
    # description come from the suite's configuration, which the executable
    # loads before this module is first referenced.
    module CLI
      extend Dry::CLI::Registry

      class << self
        # @return [String] the help's title
        def header
          p = Pastel.new
          p.green.inverse("\n #{Runtime::Configuration::DEFAULT_NAME} ") +
            p.yellow.inverse(" v#{VERSION} ") +
            p.cyan.inverse.bold(" © 2026 Konstantin Gredeskoul, MIT License     ") +
            p.cyan("") + p.reset("\n")
        end

        # Confirms which evals are running: a green box naming the suite and its
        # file, or a yellow one saying there is no file.
        #
        # @param configuration [LLM::Evals::Runtime::Configuration]
        # @param color [Boolean]
        # @param width [Integer] the box's whole width
        # @return [String]
        def dataset_conf_label(configuration:, color: false, width: IO.console&.winsize&.last || 80)
          box = StatusBox.new(width:, color:)
          return box.render(:warning, configuration.config_missing_message) unless configuration.config_found?

          box.render(:found, "Evals configuration: #{configuration.name}\nFile: #{configuration.relative_config}")
        end
      end

      # What users type, so what the help and shell completion are written for.
      # exe/llm-evals exists only for a system where `evals` is taken.
      PROGRAM = "evals".freeze

      Dry::CLI::Help::Screens::Command.prepend(OptionGroups)

      Dry::CLI::Help.configure do
        configuration = LLM::Evals.configuration

        title ::LLM::Evals::CLI.header

        types = configuration.providers.uniq(&:request_type).map do |provider|
          "#{provider.request_type} (#{provider.request_type_description})"
        end

        description "#{configuration.description} Request types: #{types.join("; ")}."

        columns = (IO.console&.winsize&.last || 80).clamp(60, 90)

        width columns.clamp(60, 120)
        exit_code_without_arguments 0

        styles do
          heading :bold, :cyan, case: :UPPERCASE
          usage :yellow
          example :yellow
          option :green
          example_comment :bright_black
        end
      end

      register "run", Run
      register "compare", Compare
      register "render", Render
      register "cases", Cases
      register "verify", Verify
      register "upgrade-config", UpgradeConfig
      register "weights", Weights
      register "version", Version, aliases: ["-V", "--version"]
      register "completion", Dry::CLI::Autocomplete::Command[self, program_name: PROGRAM]
    end
  end
end
