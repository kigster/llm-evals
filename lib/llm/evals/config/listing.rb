# frozen_string_literal: true

module LLM
  module Evals
    class Config
      # What a lineup's provider sections list: the models and the `rate_limit`s,
      # checked and read once, so that a file wrong in either way is refused
      # whichever of the two a command asks for first.
      class Listing
        # The keys a provider section may have.
        SECTION_KEYS = %w[rate_limit vendors models].freeze
        # The keys an entry under `vendors:` may have.
        VENDOR_KEYS = %w[rate_limit models].freeze
        # The keys one line under `models:` may have.
        ENTRY_KEYS = %w[model effort temperature max_tokens rate_limit].freeze

        # What marks a mapping as meant for a provider, under any name. Other
        # mappings belong to trackers and suites, so they are left alone.
        MARKERS = %w[vendors models model rate_limit].freeze

        # One line under `models:`.
        #
        # @!attribute [r] provider
        #   @return [Providers::Base] the section it was listed under
        # @!attribute [r] id
        #   @return [String] the id a provider recognises
        # @!attribute [r] settings
        #   @return [Hash{String => Object}] the line as the file has it, with `model` as a key
        Entry = Data.define(:provider, :id, :settings)

        # @return [Array<Entry>] in the file's order
        attr_reader :entries

        # @return [Hash{String => Models::Throttle::Limit}] by scope
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

        # @!attribute [r] path
        #   The lineup file, named in every error.
        #   @return [String]

        # @!attribute [r] providers
        #   Whose names the sections may use.
        #   @return [Providers::Registry]

        # @param data [Hash] the whole file
        # @return [Array<Array(Providers::Base, Hash)>] the file's provider sections
        # @raise [Error] on a retired key, an unknown provider or an unknown key
        def sections(data)
          retired = %w[vendors direct] & data.keys
          raise Error, "#{path}: #{retired.join(" and ")} no longer exist; run `evals upgrade-config` to move them under provider sections" if retired.any?

          names = providers.map(&:name)
          data.filter_map do |name, section|
            next unless section.is_a?(Hash) && (names.include?(name.to_s) || section.keys.intersect?(MARKERS))
            raise Error, "#{path}: unknown provider #{name.inspect}; known: #{names.join(", ")}" unless names.include?(name.to_s)

            known!(name, section, SECTION_KEYS)
            [providers.find { it.name == name.to_s }, section]
          end
        end

        # Collects one provider section's limits and models, those under its vendors first.
        #
        # @param provider [Providers::Base] the section's provider
        # @param section [Hash] the section as the file has it
        # @return [void]
        # @raise [Error] on a section the file format does not have
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

        # Adds each line of a `models:` list to {#entries}, and any limit it sets to {#limits}.
        #
        # @param provider [Providers::Base] the section's provider
        # @param owner [String] the vendor or provider that lists them, for errors
        # @param listing [Hash] the mapping holding `models:`
        # @param scope [String] prepended to the model name to key its limit
        # @param prefix [String] prepended to the model name to make its id
        # @return [void]
        # @raise [Error] on an entry without a model, or with an unknown key
        def list(provider, owner, listing, scope, prefix)
          Array(listing["models"]).each do |entry|
            entry = { "model" => entry } if entry.is_a?(String)
            raise Error, "#{path}: every entry under #{owner} needs a model" unless entry.is_a?(Hash) && entry["model"]

            known!(entry["model"], entry, ENTRY_KEYS)
            limit("#{scope}#{entry["model"]}", entry)
            @entries << Entry.new(provider:, id: "#{prefix}#{entry["model"]}", settings: entry)
          end
        end

        # Refuses keys the format does not have, so a typo is not ignored.
        #
        # @param owner [String] names the mapping in the error
        # @param mapping [Hash] the mapping to check
        # @param keys [Array<String>] the keys it may have
        # @return [void]
        # @raise [Error] on any other key
        def known!(owner, mapping, keys)
          unknown = mapping.keys - keys
          raise Error, "#{path}: unknown keys under #{owner}: #{unknown.join(", ")}; known: #{keys.join(", ")}" if unknown.any?
        end

        # A scope has one limit, so a model listed twice, say at two efforts, may
        # set it once: the second would otherwise replace the first in silence.
        #
        # @param scope [String] the key {Models::Throttle} looks the limit up by
        # @param owner [Hash] the mapping that may hold `rate_limit:`
        # @return [void]
        # @raise [Error] on a limit that is malformed or set twice
        def limit(scope, owner)
          given = owner["rate_limit"]
          return if given.nil?

          burst, per_minute = given.values_at("burst", "per_minute") if given.is_a?(Hash)
          unless [burst, per_minute].all? { it.is_a?(Integer) && it.positive? } && given.size == 2
            raise Error, "#{path}: rate_limit of #{scope} needs burst and per_minute, whole numbers above 0"
          end
          raise Error, "#{path}: rate_limit of #{scope} is set twice; a model listed twice shares one limit, so set it once" if @limits.key?(scope)

          @limits[scope] = Models::Throttle::Limit.new(burst:, per_minute:)
        end
      end
    end
  end
end
