# frozen_string_literal: true

require_relative "dilisense_pep_client/version"
require_relative "dilisense_pep_client/configuration"
require_relative "dilisense_pep_client/errors"
require_relative "dilisense_pep_client/client"

# Main module for the Dilisense PEP/Sanctions screening Ruby client
# Provides a simple interface for screening individuals and entities
# against PEP (Politically Exposed Persons) and sanctions lists
#
# @example Basic configuration and usage
#   # Configure the gem with your API key (usually done once at startup)
#   DilisensePepClient.configure do |config|
#     config.api_key = "your_api_key_here"
#     config.timeout = 30  # Optional: customize timeout
#   end
#
#   # Screen an individual
#   results = DilisensePepClient.check_individual(
#     names: "Vladimir Putin",
#     dob: "07/10/1952",
#     gender: "male"
#   )
#
#   # Screen an entity/company
#   results = DilisensePepClient.check_entity(names: "Bank Rossiya")
#
module DilisensePepClient
  class << self
    # Access the configuration object
    # Returns the configuration instance which holds all settings
    #
    # @return [Configuration] Configuration instance
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the gem with a block
    # This is the main way to set up the gem with your API key and preferences
    #
    # @yield [config] Configuration block
    # @yieldparam config [Configuration] The configuration object to modify
    #
    # @example Set API key and timeout
    #   DilisensePepClient.configure do |config|
    #     config.api_key = "your_api_key"
    #     config.timeout = 45
    #   end
    def configure
      yield(configuration)
    end

    # Get or create the API client instance
    # Uses singleton pattern to reuse the same client
    #
    # @return [Client] The API client instance
    def client
      @client ||= Client.new
    end

    # Convenience method to screen an individual
    # Delegates to the client's check_individual method
    #
    # @param names [String, nil] Full name to search
    # @param search_all [String, nil] Alternative search parameter
    # @param dob [String, nil] Date of birth (DD/MM/YYYY)
    # @param gender [String, nil] Gender (male/female)
    # @param fuzzy_search [Integer, nil] Fuzzy search level (1 or 2)
    # @param includes [String, nil] Source IDs to include
    # @return [Array<Hash>] Array of matching individuals
    #
    # @example Screen with multiple parameters
    #   results = DilisensePepClient.check_individual(
    #     names: "John Smith",
    #     dob: "01/01/1980",
    #     fuzzy_search: 1
    #   )
    def check_individual(names: nil, search_all: nil, dob: nil, gender: nil, fuzzy_search: nil, includes: nil)
      client.check_individual(names: names, search_all: search_all, dob: dob, gender: gender, fuzzy_search: fuzzy_search, includes: includes)
    end

    # Convenience method to screen an entity/company
    # Delegates to the client's check_entity method
    #
    # @param names [String, nil] Entity name to search
    # @param search_all [String, nil] Alternative search parameter
    # @param fuzzy_search [Integer, nil] Fuzzy search level (1 or 2)
    # @return [Array<Hash>] Array of matching entities
    #
    # @example Screen a company
    #   results = DilisensePepClient.check_entity(names: "Apple Inc")
    def check_entity(names: nil, search_all: nil, fuzzy_search: nil)
      client.check_entity(names: names, search_all: search_all, fuzzy_search: fuzzy_search)
    end

    # Reset the gem to its initial state
    # Clears configuration and client instance
    # Useful for testing or reconfiguration
    #
    # @return [nil]
    def reset!
      @configuration = nil
      @client = nil
    end
  end
end