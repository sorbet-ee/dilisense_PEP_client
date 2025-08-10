# frozen_string_literal: true

require "dry-validation"

module DilisensePepClient
  # Industrial-grade input validation and sanitization system
  # 
  # This class provides comprehensive input validation and sanitization specifically designed
  # for financial services applications that handle sensitive PEP/sanctions screening data.
  # It ensures data integrity, prevents injection attacks, and maintains compliance with
  # security standards for financial institutions.
  #
  # Features:
  # - Declarative validation contracts using dry-validation
  # - Comprehensive input sanitization with security focus
  # - API key format validation and security logging
  # - Response data sanitization with size limits
  # - Unicode normalization and dangerous character removal
  # - Detailed error messages with context for debugging
  # - Audit logging for validation events and security incidents
  # - Protection against oversized responses and DoS attacks
  #
  # The validator handles two main screening types:
  # - Individual screening: Personal data with DOB, gender, names
  # - Entity screening: Company/organization names and identifiers
  #
  # All validation failures are logged as security events for monitoring and compliance.
  # Sensitive data is automatically redacted in logs and error messages.
  #
  # @example Individual screening validation
  #   params = { names: "John Smith", dob: "01/01/1980", gender: "male" }
  #   validated = Validator.validate_individual_params(params)
  #
  # @example Entity screening validation
  #   params = { names: "Apple Inc", fuzzy_search: 1 }
  #   validated = Validator.validate_entity_params(params)
  #
  # @example API key validation
  #   sanitized_key = Validator.sanitize_api_key(raw_api_key)
  class Validator
    # Individual screening parameters validation contract
    # Defines validation rules for person-based PEP screening with comprehensive checks
    # for data format, mutual exclusivity, and security constraints
    IndividualContract = Dry::Validation.Contract do
      params do
        optional(:names).maybe(:string)
        optional(:search_all).maybe(:string)
        optional(:dob).maybe(:string)
        optional(:gender).maybe(:string)
        optional(:fuzzy_search).maybe(:integer)
        optional(:includes).maybe(:string)
      end

      rule(:names, :search_all) do
        if values[:names] && values[:search_all]
          key.failure("cannot use both 'names' and 'search_all' parameters")
        end
      end

      rule(:names, :search_all) do
        unless values[:names] || values[:search_all]
          key.failure("either 'names' or 'search_all' parameter is required")
        end
      end

      rule(:dob) do
        if value && !valid_date_format?(value)
          key.failure("must be in format DD/MM/YYYY, 00/MM/YYYY, DD/00/YYYY, or 00/00/YYYY")
        end
      end

      rule(:gender) do
        if value && !%w[male female].include?(value.downcase)
          key.failure("must be 'male' or 'female'")
        end
      end

      rule(:fuzzy_search) do
        if value && ![1, 2].include?(value)
          key.failure("must be 1 or 2")
        end
      end

      rule(:names) do
        if value && (value.length > 200 || value.strip.empty?)
          key.failure("must be between 1 and 200 characters")
        end
      end

      rule(:search_all) do
        if value && (value.length > 200 || value.strip.empty?)
          key.failure("must be between 1 and 200 characters")
        end
      end

      private

      def valid_date_format?(date_str)
        # Validate DD/MM/YYYY format with flexible day/month
        return false unless date_str.match?(/^\d{2}\/\d{2}\/\d{4}$/)
        
        parts = date_str.split("/")
        day, month, year = parts.map(&:to_i)
        
        # Validate year (reasonable range)
        return false if year < 1900 || year > Date.today.year + 10
        
        # Allow 00 for unknown day/month
        return false if day > 31 || month > 12
        return false if day < 0 || month < 0
        
        true
      end
    end

    # Entity screening parameters validation contract  
    # Defines validation rules for company/organization-based screening with focus
    # on entity name formats and organizational identifier validation
    EntityContract = Dry::Validation.Contract do
      params do
        optional(:names).maybe(:string)
        optional(:search_all).maybe(:string)
        optional(:fuzzy_search).maybe(:integer)
      end

      rule(:names, :search_all) do
        if values[:names] && values[:search_all]
          key.failure("cannot use both 'names' and 'search_all' parameters")
        end
      end

      rule(:names, :search_all) do
        unless values[:names] || values[:search_all]
          key.failure("either 'names' or 'search_all' parameter is required")
        end
      end

      rule(:fuzzy_search) do
        if value && ![1, 2].include?(value)
          key.failure("must be 1 or 2")
        end
      end

      rule(:names) do
        if value && (value.length > 300 || value.strip.empty?)
          key.failure("must be between 1 and 300 characters")
        end
      end

      rule(:search_all) do
        if value && (value.length > 300 || value.strip.empty?)
          key.failure("must be between 1 and 300 characters")
        end
      end
    end

    class << self
      # Validate and sanitize individual screening parameters
      # Applies comprehensive validation rules and sanitization for person-based screening
      #
      # @param params [Hash] Raw input parameters from user/API
      # @return [Hash] Validated and sanitized parameters
      # @raise [ValidationError] When validation rules fail
      #
      # @example Valid individual parameters
      #   params = {
      #     names: "John Smith", 
      #     dob: "15/06/1985", 
      #     gender: "male",
      #     fuzzy_search: 1
      #   }
      #   validated = validate_individual_params(params)
      def validate_individual_params(params)
        sanitized_params = sanitize_individual_params(params)
        result = IndividualContract.call(sanitized_params)
        
        if result.failure?
          error_messages = extract_error_messages(result.errors)
          raise ValidationError.new(
            "Invalid individual screening parameters",
            validation_errors: error_messages,
            context: { 
              sanitized_params: sanitized_params,
              original_params_keys: params.keys 
            }
          )
        end

        # Log validation success for audit trail
        Logger.logger.debug("Individual params validation successful", {
          sanitized_params: sanitized_params,
          validation_rules_applied: %w[
            mutual_exclusion name_format length_limits
            date_format gender_values fuzzy_search_range
          ]
        })

        result.to_h
      end

      def validate_entity_params(params)
        sanitized_params = sanitize_entity_params(params)
        result = EntityContract.call(sanitized_params)
        
        if result.failure?
          error_messages = extract_error_messages(result.errors)
          raise ValidationError.new(
            "Invalid entity screening parameters",
            validation_errors: error_messages,
            context: { 
              sanitized_params: sanitized_params,
              original_params_keys: params.keys 
            }
          )
        end

        # Log validation success for audit
        Logger.logger.debug("Entity params validation successful", {
          sanitized_params: sanitized_params,
          validation_rules_applied: %w[
            mutual_exclusion name_format length_limits fuzzy_search_range
          ]
        })

        result.to_h
      end

      def sanitize_api_key(api_key)
        return nil if api_key.nil? || api_key.to_s.strip.empty?
        
        key = api_key.to_s.strip
        
        # Validate API key format (basic checks)
        unless valid_api_key_format?(key)
          raise ConfigurationError.new(
            "Invalid API key format",
            config_key: "api_key",
            context: { 
              key_length: key.length,
              key_format: detect_key_format(key)
            }
          )
        end

        # Log API key validation (without exposing the key)
        Logger.log_security_event(
          event_type: "api_key_validation",
          details: {
            key_length: key.length,
            key_format: detect_key_format(key),
            validation_result: "success"
          },
          severity: :low
        )

        key
      end

      def sanitize_response_data(data, max_size: 1_048_576) # 1MB default
        return nil unless data
        
        # Check response size
        data_size = data.to_s.bytesize
        if data_size > max_size
          Logger.log_security_event(
            event_type: "oversized_response",
            details: {
              response_size: data_size,
              max_allowed: max_size,
              truncated: true
            },
            severity: :medium
          )
          
          # Truncate large responses
          truncated_data = data.to_s[0, max_size]
          return "#{truncated_data}... [TRUNCATED: original size #{data_size} bytes]"
        end

        # Sanitize potentially sensitive data patterns
        sanitized = data.to_s.gsub(
          /\b(?:api[_-]?key|token|secret|password)\s*[=:]\s*[^\s&]+/i,
          '[REDACTED_CREDENTIAL]'
        )

        sanitized
      end

      private

      def sanitize_individual_params(params)
        return {} unless params.is_a?(Hash)
        
        sanitized = {}
        
        params.each do |key, value|
          sanitized_key = key.to_sym
          sanitized_value = case sanitized_key
          when :names, :search_all
            sanitize_name_input(value)
          when :dob
            sanitize_date_input(value)
          when :gender
            sanitize_gender_input(value)
          when :fuzzy_search
            sanitize_integer_input(value, min: 1, max: 2)
          when :includes
            sanitize_includes_input(value)
          else
            # Unknown parameter - log and ignore
            Logger.log_security_event(
              event_type: "unknown_parameter",
              details: {
                parameter_name: key,
                parameter_value: value.to_s[0, 50],
                context: "individual_screening"
              },
              severity: :low
            )
            next
          end
          
          sanitized[sanitized_key] = sanitized_value if sanitized_value
        end

        sanitized
      end

      def sanitize_entity_params(params)
        return {} unless params.is_a?(Hash)
        
        sanitized = {}
        
        params.each do |key, value|
          sanitized_key = key.to_sym
          sanitized_value = case sanitized_key
          when :names, :search_all
            sanitize_name_input(value, max_length: 300)
          when :fuzzy_search
            sanitize_integer_input(value, min: 1, max: 2)
          else
            # Unknown parameter - log and ignore
            Logger.log_security_event(
              event_type: "unknown_parameter",
              details: {
                parameter_name: key,
                parameter_value: value.to_s[0, 50],
                context: "entity_screening"
              },
              severity: :low
            )
            next
          end
          
          sanitized[sanitized_key] = sanitized_value if sanitized_value
        end

        sanitized
      end

      def sanitize_name_input(value, max_length: 200)
        return nil if value.nil?
        
        name = value.to_s.strip
        return nil if name.empty?
        
        # Remove potentially dangerous characters
        name = name.gsub(/[<>\"'&\x00-\x1F\x7F-\x9F]/, '')
        
        # Normalize unicode and whitespace
        name = name.unicode_normalize(:nfc).squeeze(' ')
        
        # Truncate if too long
        name = name[0, max_length] if name.length > max_length
        
        # Final validation
        return nil if name.strip.empty?
        
        name
      end

      def sanitize_date_input(value)
        return nil if value.nil?
        
        date_str = value.to_s.strip
        return nil if date_str.empty?
        
        # Only allow specific date format
        return nil unless date_str.match?(/^\d{2}\/\d{2}\/\d{4}$/)
        
        date_str
      end

      def sanitize_gender_input(value)
        return nil if value.nil?
        
        gender = value.to_s.strip.downcase
        return nil unless %w[male female].include?(gender)
        
        gender
      end

      def sanitize_integer_input(value, min: nil, max: nil)
        return nil if value.nil?
        
        int_value = case value
        when Integer then value
        when String then value.to_i if value.match?(/^\d+$/)
        else nil
        end
        
        return nil unless int_value
        return nil if min && int_value < min
        return nil if max && int_value > max
        
        int_value
      end

      def sanitize_includes_input(value)
        return nil if value.nil?
        
        includes = value.to_s.strip
        return nil if includes.empty?
        
        # Basic validation for source IDs (alphanumeric, underscore, comma, space)
        return nil unless includes.match?(/^[a-zA-Z0-9_,\s]+$/)
        
        # Normalize and clean up
        includes.gsub(/\s+/, ' ').strip
      end

      def valid_api_key_format?(key)
        # Basic API key format validation
        return false if key.length < 10 || key.length > 200
        
        # Check for reasonable character set
        key.match?(/^[a-zA-Z0-9._-]+$/)
      end

      def detect_key_format(key)
        case key.length
        when 10..50 then "short_key"
        when 51..100 then "medium_key"
        when 101..200 then "long_key"
        else "unknown"
        end
      end

      def extract_error_messages(errors)
        errors.to_h.map do |field, messages|
          Array(messages).map { |msg| "#{field}: #{msg}" }
        end.flatten
      end
    end
  end
end