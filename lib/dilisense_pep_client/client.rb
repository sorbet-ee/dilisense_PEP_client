# frozen_string_literal: true

require "faraday"
require "json"

module DilisensePepClient
  class Client
    def initialize(config = DilisensePepClient.configuration)
      @config = config
      validate_configuration!
      @connection = build_connection
    end

    def check_individual(names: nil, search_all: nil, dob: nil, gender: nil, fuzzy_search: nil, includes: nil)
      params = build_individual_params(names: names, search_all: search_all, dob: dob, gender: gender, fuzzy_search: fuzzy_search, includes: includes)
      validate_individual_params(params)
      get_request("/v1/checkIndividual", params)
    end

    def check_entity(params = {})
      validate_entity_params(params)
      get_request("/v1/checkEntity", params)
    end

    private

    def validate_configuration!
      raise ConfigurationError, "API key is required" if @config.api_key.nil? || @config.api_key.empty?
    end

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

    def validate_individual_params(params)
      if params[:search_all] && params[:names]
        raise ValidationError, "Cannot use both search_all and names parameters"
      end
      unless params[:search_all] || params[:names]
        raise ValidationError, "Either search_all or names parameter is required"
      end
    end

    def validate_entity_params(params)
      if params[:search_all] && params[:names]
        raise ValidationError, "Cannot use both search_all and names parameters"
      end
      unless params[:search_all] || params[:names]
        raise ValidationError, "Either search_all or names parameter is required"
      end
    end

    def build_connection
      Faraday.new(url: @config.base_url) do |f|
        f.options.timeout = @config.timeout
        f.headers["x-api-key"] = @config.api_key
        f.headers["User-Agent"] = "DilisensePepClient/#{VERSION}"
      end
    end

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

      # Convert each group to a person object
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
          sources: all_sources,
          total_records: records.length,
          raw_records: records
        }
      end
    end

    def normalize_name(name)
      return "" unless name
      
      # Remove common variations and normalize for grouping
      normalized = name.downcase
        .gsub(/\s+/, " ")           # Normalize whitespace
        .gsub(/[^\w\s]/, "")        # Remove punctuation
        .strip
      
      # Handle common name variations
      normalized.gsub(/\b(jr|sr|iii?|iv)\b/, "")  # Remove suffixes
        .gsub(/\s+/, " ")
        .strip
    end
  end
end