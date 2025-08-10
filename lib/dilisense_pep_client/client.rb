# frozen_string_literal: true

require "faraday"
require "json"

module DilisensePepClient
  # Main client class for interacting with the Dilisense PEP/Sanctions screening API
  # This class handles all API communication and response processing
  #
  # @example Basic usage for individual screening
  #   client = DilisensePepClient::Client.new
  #   results = client.check_individual(names: "John Smith")
  #
  # @example Entity screening
  #   results = client.check_entity(names: "Apple Inc")
  class Client
    # Initialize a new API client
    # Validates configuration and establishes HTTP connection
    # @raise [ConfigurationError] if API key is missing or invalid
    def initialize
      validate_configuration!
      @connection = build_connection
    end

    # Screen an individual against PEP and sanctions lists
    #
    # @param names [String, nil] Full name to search for (e.g., "John Smith")
    # @param search_all [String, nil] Alternative to names parameter for broader search
    # @param dob [String, nil] Date of birth in DD/MM/YYYY format (e.g., "14/06/1982")
    # @param gender [String, nil] Gender - either "male" or "female"
    # @param fuzzy_search [Integer, nil] Enable fuzzy matching: 1 for fuzzy, 2 for very fuzzy
    # @param includes [String, nil] Comma-separated source IDs to search within
    #
    # @return [Array<Hash>] Array of matched individuals, each hash contains:
    #   - :name [String] Person's full name
    #   - :source_type [String] Type of source (PEP, SANCTION, etc.)
    #   - :pep_type [String, nil] Type of PEP if applicable
    #   - :gender [String, nil] Person's gender if available
    #   - :date_of_birth [Array<String>, nil] Dates of birth if available
    #   - :citizenship [Array<String>, nil] Countries of citizenship
    #   - :total_records [Integer] Number of matching records
    #   - :sources [Array<String>] List of source databases
    #
    # @example Search with full parameters
    #   results = client.check_individual(
    #     names: "Vladimir Putin",
    #     dob: "07/10/1952",
    #     gender: "male",
    #     fuzzy_search: 1
    #   )
    #
    # @raise [ValidationError] if parameters are invalid or conflicting
    # @raise [APIError] if the API returns an error
    def check_individual(names: nil, search_all: nil, dob: nil, gender: nil, fuzzy_search: nil, includes: nil)
      params = build_individual_params(names: names, search_all: search_all, dob: dob, gender: gender, fuzzy_search: fuzzy_search, includes: includes)
      validate_individual_params(params)
      get_request("/v1/checkIndividual", params)
    end

    # Screen an entity (company/organization) against sanctions and watchlists
    #
    # @param names [String, nil] Entity name to search for (e.g., "Apple Inc")
    # @param search_all [String, nil] Alternative parameter for broader entity search
    # @param fuzzy_search [Integer, nil] Enable fuzzy matching: 1 for fuzzy, 2 for very fuzzy
    #
    # @return [Array<Hash>] Array of matched entities with details
    #
    # @example Basic entity search
    #   results = client.check_entity(names: "Bank Rossiya")
    #
    # @example Fuzzy search for entities
    #   results = client.check_entity(names: "Gazprom", fuzzy_search: 1)
    #
    # @raise [ValidationError] if parameters are invalid
    # @raise [APIError] if the API returns an error
    def check_entity(names: nil, search_all: nil, fuzzy_search: nil)
      params = {}
      params[:names] = names if names
      params[:search_all] = search_all if search_all
      params[:fuzzy_search] = fuzzy_search if fuzzy_search
      
      validate_entity_params(params)
      get_request("/v1/checkEntity", params)
    end

    private

    # Validate that the API configuration is properly set
    # Checks for presence and validity of API key
    # @raise [ConfigurationError] if API key is missing or empty
    def validate_configuration!
      config = DilisensePepClient.configuration
      raise ConfigurationError, "API key is required" if config.api_key.nil? || config.api_key.empty?
    end

    # Build parameters hash for individual screening API call
    # Filters out nil values to keep request clean
    #
    # @param names [String, nil] Person's full name
    # @param search_all [String, nil] Alternative search parameter
    # @param dob [String, nil] Date of birth (DD/MM/YYYY)
    # @param gender [String, nil] Gender (male/female)
    # @param fuzzy_search [Integer, nil] Fuzzy search level (1 or 2)
    # @param includes [String, nil] Source IDs to include
    # @return [Hash] Parameters hash with non-nil values only
    def build_individual_params(names:, search_all:, dob:, gender:, fuzzy_search:, includes:)
      params = {}
      params[:names] = names if names
      params[:search_all] = search_all if search_all
      params[:dob] = dob if dob
      params[:gender] = gender if gender
      params[:fuzzy_search] = fuzzy_search if fuzzy_search
      params[:includes] = includes if includes
      params
    end

    # Validate parameters for individual screening
    # Ensures mutually exclusive parameters aren't used together
    # and that at least one search parameter is provided
    #
    # @param params [Hash] Parameters to validate
    # @raise [ValidationError] if parameters are invalid or missing
    def validate_individual_params(params)
      # Can't use both 'names' and 'search_all' - they're mutually exclusive
      if params[:search_all] && params[:names]
        raise ValidationError, "Cannot use both search_all and names parameters"
      end
      # Must have at least one search parameter
      unless params[:search_all] || params[:names]
        raise ValidationError, "Either search_all or names parameter is required"
      end
    end

    # Validate parameters for entity screening
    # Similar to individual validation but for entities
    #
    # @param params [Hash] Parameters to validate
    # @raise [ValidationError] if parameters are invalid
    def validate_entity_params(params)
      # Can't use both search methods simultaneously
      if params[:search_all] && params[:names]
        raise ValidationError, "Cannot use both search_all and names parameters"
      end
      # Need at least one search parameter
      unless params[:search_all] || params[:names]
        raise ValidationError, "Either search_all or names parameter is required"
      end
    end

    # Build the HTTP connection using Faraday
    # Sets up headers, timeout, and authentication
    #
    # @return [Faraday::Connection] Configured HTTP client
    def build_connection
      config = DilisensePepClient.configuration
      Faraday.new(url: config.base_url) do |f|
        f.options.timeout = config.timeout
        f.headers["x-api-key"] = config.api_key  # API authentication
        f.headers["User-Agent"] = "DilisensePepClient/#{VERSION}"  # Identify our client
      end
    end

    # Execute GET request to the API and process response
    # Handles network errors and converts response to array format
    #
    # @param endpoint [String] API endpoint path (e.g., "/v1/checkIndividual")
    # @param params [Hash] Query parameters for the request
    # @return [Array<Hash>] Processed response as array of matches
    # @raise [NetworkError] if connection fails or times out
    # @raise [APIError] if API returns an error status
    def get_request(endpoint, params)
      response = @connection.get(endpoint, params)
      raw_response = handle_response(response)
      process_response_to_array(raw_response)
    rescue Faraday::TimeoutError
      raise NetworkError, "Request timeout"
    rescue Faraday::ConnectionFailed
      raise NetworkError, "Connection failed"
    end

    def handle_response(response)
      case response.status
      when 200
        JSON.parse(response.body)
      when 401
        raise AuthenticationError.new("API key not valid", status: response.status, body: response.body)
      when 400
        raise ValidationError.new("Bad request: #{response.body}", status: response.status, body: response.body)
      when 403
        raise APIError.new("Forbidden", status: response.status, body: response.body)
      when 429
        raise APIError.new("Rate limit exceeded", status: response.status, body: response.body)
      when 500
        raise APIError.new("Internal server error", status: response.status, body: response.body)
      else
        raise APIError.new("Unexpected response: #{response.status}", status: response.status, body: response.body)
      end
    rescue JSON::ParserError
      raise APIError.new("Invalid JSON response", status: response.status, body: response.body)
    end

    def process_response_to_array(raw_response)
      return [] if raw_response["total_hits"] == 0

      # Group records by person (using name as the key)
      person_groups = raw_response["found_records"].group_by do |record|
        normalize_name(record["name"])
      end

      # Convert each group to a person/entity object
      person_groups.map do |normalized_name, records|
        primary_record = records.first
        all_sources = records.map { |r| r["source_id"] }.uniq

        {
          name: primary_record["name"],
          source_type: primary_record["source_type"],
          pep_type: primary_record["pep_type"],
          gender: primary_record["gender"],
          date_of_birth: primary_record["date_of_birth"],
          citizenship: primary_record["citizenship"],
          jurisdiction: primary_record["jurisdiction"],
          address: primary_record["address"],
          sanction_details: primary_record["sanction_details"],
          sources: all_sources,
          total_records: records.length,
          raw_records: records
        }
      end
    end

    # Normalize a name for comparison/grouping purposes
    # Handles various name formats and removes titles/suffixes
    # This ensures "Mr. John Smith Jr." and "JOHN SMITH" are treated as the same person
    #
    # @param name [String] Name to normalize
    # @return [String] Normalized name for comparison
    def normalize_name(name)
      return "" unless name
      
      # Remove common variations and normalize for grouping
      normalized = name.downcase
        .gsub(/\s+/, " ")           # Normalize whitespace (multiple spaces -> single space)
        .gsub(/[^\w\s]/, "")        # Remove punctuation (periods, commas, etc.)
        .strip                       # Remove leading/trailing whitespace
      
      # Handle common name variations - remove suffixes that don't affect identity
      # This helps match "John Smith Jr." with "John Smith"
      normalized.gsub(/\b(jr|sr|iii?|iv)\b/, "")  # Remove suffixes (Jr, Sr, III, IV, etc.)
        .gsub(/\s+/, " ")           # Clean up any double spaces from removal
        .strip
    end
  end
end