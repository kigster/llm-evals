# frozen_string_literal: true

require "dotenv"

module LLM
  module Evals
    module Runtime
      # One-time process setup: secrets from the suite's env files, a check that
      # every key and gem the run needs is there, the suite's own hooks, and
      # the providers' clients.
      class Environment
        attr_reader :env_files, :hooks, :app_name

        # @!attribute [r] env_files
        #   Absolute paths; those that exist load.
        #   @return [Array<String>]

        # @!attribute [r] hooks
        #   The suite's `before_run` blocks.
        #   @return [Array<Proc>]

        # @!attribute [r] app_name
        #   What a provider tells its API the caller is.
        #   @return [String]

        # @param env_files [Array<String>] absolute paths; those that exist load
        # @param hooks [Array<Proc>] the suite's `before_run` blocks
        # @param app_name [String] what a provider tells its API the caller is
        def initialize(env_files: [], hooks: [], app_name: "llm-evals")
          @env_files = env_files
          @hooks = hooks
          @app_name = app_name
        end

        # Loads the env files that exist, without overriding what is already
        # set, so an exported variable beats the file.
        #
        # @return [void]
        def load_env
          files = env_files.select { File.exist?(it) }
          Dotenv.load(*files) unless files.empty?
        end

        # Fails before anything is called when a key the run needs is neither
        # exported nor in an env file.
        #
        # @param names [Array<String>] variable names; repeats are fine
        # @return [void]
        # @raise [Error] naming every missing variable
        def require_env!(names)
          missing = names.uniq.select { ENV[it].to_s.strip.empty? }
          return if missing.empty?

          found = env_files.select { File.exist?(it) }
          where = if found.empty?
                    env_files.empty? ? "no env files are configured" : "there is no #{env_files.join(" or ")}"
                  else
                    "checked the environment, then #{found.join(", ")}"
                  end
          raise Error,
            "missing #{missing.join(", ")}: export them or add them to an env file (#{where}); " \
            "an exported blank value wins over the file"
        end

        # Readies the process for a run: env files, checks, hooks, then provider clients, in that order.
        #
        # @param providers [Array<Providers::Base>] the providers the run's models use
        # @param tracker [Class<Trackers::Base>, nil] the remote tracker chosen, whose gems and key are checked too
        # @return [void]
        # @raise [Error] when a needed variable or gem is missing
        def setup!(providers: [], tracker: nil)
          load_env
          require_env!(providers.flat_map(&:env_keys))
          tracker&.requirements!(ENV)
          hooks.each(&:call) # after load_env: a hook usually re-reads ENV
          providers.each { it.setup!(app_name: app_name) }
        end

        # Opens a URL in the desktop browser.
        #
        # @param url [String] the page to open
        # @return [Boolean] whether the opener ran
        def browse(url)
          opener = RUBY_PLATFORM.include?("darwin") ? "open" : "xdg-open"
          system(opener, url, out: File::NULL, err: File::NULL) || false
        end
      end
    end
  end
end
