# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # What a lineup's provider sections list: the models and the `rate_limit`s,
      # checked and read once, so that a file wrong in either way is refused
      # whichever of the two a command asks for first.
      class Listing
        SECTION_KEYS = %w[rate_limit vendors models].freeze
        VENDOR_KEYS = %w[rate_limit models].freeze
        ENTRY_KEYS = %w[model effort temperature max_tokens rate_limit].freeze

        # One line under `models:`.
        Entry = Data.define(:provider, :id, :settings)

        # @return [Array<Entry>] in the file's order
        attr_reader :entries

        # @return [Hash{String => Throttle::Limit}] by scope
        attr_reader :limits

        # @param data [Hash] the whole file
        # @param path [String] named in every error
        # @param providers [Providers::Registry] whose names the sections may use
        # @raise [Error] on a section, entry or limit the file format does not have
        def initialize(data, path:, providers:)
          @path = path
          @providers = providers
          @entries = []
          @limits = {}
          sections(data).each { |provider, section| read(provider, section) }
        end

        private

        attr_reader :path, :providers

        # @return [Array<Array(Providers::Base, Hash)>] the file's provider sections
        def sections(data)
          retired = %w[vendors direct] & data.keys
          raise Error, "#{path}: #{retired.join(" and ")} no longer exist; run `evals upgrade-config` to move them under provider sections" if retired.any?

          names = providers.map(&:name)
          data.filter_map do |name, section|
            next unless section.is_a?(Hash) && section.keys.intersect?(%w[vendors models])
            raise Error, "#{path}: unknown provider #{name.inspect}; known: #{names.join(", ")}" unless names.include?(name.to_s)

            known!(name, section, SECTION_KEYS)
            [providers.find { it.name == name.to_s }, section]
          end
        end

        def read(provider, section)
          limit(provider.name, section)
          vendors = section["vendors"] || {}
          raise Error, "#{path}: vendors must be a mapping of vendor to models" unless vendors.is_a?(Hash)

          vendors.each do |vendor, listing|
            raise Error, "#{path}: vendor #{vendor} needs a models: list" unless listing.is_a?(Hash)

            known!(vendor, listing, VENDOR_KEYS)
            limit("#{provider.name}/#{vendor}", listing)
            list(provider, vendor, listing, "#{provider.name}/#{vendor}/", "#{provider.prefix}#{vendor}/")
          end
          list(provider, provider.name, section, "#{provider.name}/", provider.prefix.to_s)
        end

        def list(provider, owner, listing, scope, prefix)
          Array(listing["models"]).each do |entry|
            entry = { "model" => entry } if entry.is_a?(String)
            raise Error, "#{path}: every entry under #{owner} needs a model" unless entry.is_a?(Hash) && entry["model"]

            known!(entry["model"], entry, ENTRY_KEYS)
            limit("#{scope}#{entry["model"]}", entry)
            @entries << Entry.new(provider:, id: "#{prefix}#{entry["model"]}", settings: entry)
          end
        end

        def known!(owner, mapping, keys)
          unknown = mapping.keys - keys
          raise Error, "#{path}: unknown keys under #{owner}: #{unknown.join(", ")}; known: #{keys.join(", ")}" if unknown.any?
        end

        # A scope has one limit, so a model listed twice, say at two efforts, may
        # set it once: the second would otherwise replace the first in silence.
        def limit(scope, owner)
          given = owner["rate_limit"]
          return if given.nil?

          burst, per_minute = given.values_at("burst", "per_minute") if given.is_a?(Hash)
          unless [burst, per_minute].all? { it.is_a?(Integer) && it.positive? } && given.size == 2
            raise Error, "#{path}: rate_limit of #{scope} needs burst and per_minute, whole numbers above 0"
          end
          raise Error, "#{path}: rate_limit of #{scope} is set twice; a model listed twice shares one limit, so set it once" if @limits.key?(scope)

          @limits[scope] = Throttle::Limit.new(burst:, per_minute:)
        end
      end
    end
  end
end
