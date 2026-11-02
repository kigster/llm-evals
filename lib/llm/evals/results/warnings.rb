# frozen_string_literal: true

require "logger"

module LLM
  module Evals
    module Results
      # Everything a run would otherwise print as a warning while its progress
      # bars redraw: cases that failed, and what Braintrust, RubyLLM, OpenTelemetry
      # (whose exporters report failures on $stdout) and Ruby itself log. Printed among the bars, each one breaks the redraw; collected
      # here, they are saved to one file, and the run prints only how many.
      #
      # It quacks as an IO, so a Logger, and $stderr, can write to it. Threads
      # share it.
      class Warnings
        # Starts empty, with the lock every reader and writer below shares.
        def initialize
          @lines = []
          @lock = Mutex.new
        end

        # Keeps one warning, dropping trailing newlines and anything blank.
        #
        # @param text [#to_s]
        # @return [self]
        def record(text)
          text = text.to_s.chomp
          @lock.synchronize { @lines << text } unless text.strip.empty?
          self
        end

        # IO#write, for a Logger or $stderr writing here. Each argument is one warning.
        #
        # @param texts [Array<#to_s>]
        # @return [Integer] the bytes "written", as IO#write does
        def write(*texts)
          texts.each { record(it) }
          texts.sum { it.to_s.bytesize }
        end

        # IO#puts, for code holding this as $stderr.
        #
        # @param texts [Array<#to_s>] one warning each
        # @return [nil]
        def puts(*texts) = texts.each { record(it) } && nil
        # IO#print, for code holding this as $stderr.
        #
        # @param texts [Array<#to_s>] one warning each
        # @return [nil]
        def print(*texts) = write(*texts) && nil
        # IO#<<, chainable as on an IO.
        #
        # @param text [#to_s]
        # @return [self]
        def <<(text) = record(text)
        # IO#flush; nothing is buffered, so there is nothing to do.
        #
        # @return [self]
        def flush = self
        # IO#sync; records are always kept at once.
        #
        # @return [Boolean] always true
        def sync = true
        # IO#sync=; ignored, since {#sync} cannot be anything but true.
        #
        # @param _value [Boolean]
        # @return [void]
        def sync=(_value); end
        # IO#close; ignored, so a Logger closing its device cannot lose the warnings.
        #
        # @return [nil]
        def close = nil
        # IO#tty?; false tells a writer not to emit terminal control codes here.
        #
        # @return [Boolean] always false
        def tty? = false

        # Safe to call while other threads are still recording.
        #
        # @return [Integer]
        def count = @lock.synchronize { @lines.size }

        # A copy, so a caller cannot change what was recorded.
        #
        # @return [Array<String>]
        def to_a = @lock.synchronize { @lines.dup }

        # Lets a caller skip saving an empty file.
        #
        # @return [Boolean] whether nothing was recorded
        def none? = count.zero?

        # Writes the warnings to a file, separated by blank lines, replacing what was there.
        #
        # @param path [String]
        # @return [String] the path
        def save(path)
          File.write(path, "#{to_a.join("\n\n")}\n")
          path
        end

        # Runs the block with $stderr, Ruby's own warnings, and the loggers of
        # whichever optional gems are loaded writing here, and puts them back after.
        #
        # @example
        #   warnings.capture { warn "deprecated" }
        #   warnings.to_a # => ["deprecated"]
        # @yield runs with the output redirected; everything is restored afterwards, even if it raises
        # @return [Object] what the block returns
        def capture
          logger = Logger.new(self, level: Logger::WARN)
          stderr = $stderr
          kernel_warn = Kernel.instance_method(:warn)
          warnings = self
          restore = redirect_loggers(logger)
          $stderr = self
          Kernel.define_method(:warn) { |*messages, **_options| warnings.write(messages.join("\n")) }
          Kernel.send(:private, :warn)
          yield
        ensure
          Kernel.define_method(:warn, kernel_warn) if kernel_warn
          Kernel.send(:private, :warn)
          restore&.call
          $stderr = stderr
        end

        private

        # Points the optional gems' loggers at the one given, for the gems that are loaded.
        #
        # @param logger [Logger] writes here
        # @return [Proc] puts the loggers back
        def redirect_loggers(logger)
          braintrust = defined?(Braintrust::Log) ? Braintrust::Log.logger : nil
          ruby_llm = defined?(RubyLLM) ? RubyLLM.instance_variable_get(:@logger) : nil
          open_telemetry = defined?(OpenTelemetry) ? OpenTelemetry.logger : nil
          Braintrust::Log.logger = logger if defined?(Braintrust::Log)
          RubyLLM.instance_variable_set(:@logger, logger) if defined?(RubyLLM)
          OpenTelemetry.logger = logger if defined?(OpenTelemetry)
          lambda do
            Braintrust::Log.logger = braintrust if defined?(Braintrust::Log)
            RubyLLM.instance_variable_set(:@logger, ruby_llm) if defined?(RubyLLM)
            OpenTelemetry.logger = open_telemetry if defined?(OpenTelemetry)
          end
        end
      end
    end
  end
end
