# frozen_string_literal: true

module DilisensePepClient
  # Base error class for all DilisensePepClient exceptions
  # Provides enhanced error handling with context, timestamps, and request tracking
  # All other error classes inherit from this base class
  #
  # @example Catching any gem error
  #   begin
  #     DilisensePepClient.check_individual(names: "John")
  #   rescue DilisensePepClient::Error => e
  #     puts "Error: #{e.message}"
  #     puts "Error code: #{e.error_code}"
  #     puts "Request ID: #{e.request_id}"
  #   end
  class Error < StandardError
    attr_reader :error_code, :context, :timestamp, :request_id

    def initialize(message, error_code: nil, context: {}, request_id: nil)
      super(message)
      @error_code = error_code
      @context = context || {}
      @timestamp = Time.now.utc.iso8601
      @request_id = request_id || generate_request_id
      
      log_error
    end

    def to_h
      {
        error_type: self.class.name,
        message: message,
        error_code: error_code,
        context: context,
        timestamp: timestamp,
        request_id: request_id,
        backtrace: backtrace&.first(10)
      }
    end

    def retryable?
      false
    end

    def security_event?
      false
    end

    private

    def log_error
      return unless defined?(DilisensePepClient::Logger)
      
      severity = security_event? ? :error : :warn
      
      DilisensePepClient::Logger.logger.send(severity, "#{self.class.name} raised", {
        error_code: error_code,
        message: message,
        context: context,
        request_id: request_id,
        retryable: retryable?
      })
    end

    def generate_request_id
      require "securerandom"
      SecureRandom.hex(8)
    end
  end

  # Raised when there's a problem with gem configuration
  # Usually means the API key is missing or invalid
  #
  # @example Common cause - missing API key
  #   # This will raise ConfigurationError if API key not set
  #   client = DilisensePepClient::Client.new
  class ConfigurationError < Error
    def initialize(message, config_key: nil, config_value: nil, **options)
      context = {
        config_key: config_key,
        config_value: sanitize_config_value(config_value)
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "CONFIG_ERROR", context: context, **options)
    end

    def security_event?
      context[:config_key]&.to_s&.match?(/api_key|secret|token/)
    end

    private

    def sanitize_config_value(value)
      return "[REDACTED]" if value.to_s.match?(/api_key|secret|token|password/i)
      value.to_s.length > 50 ? "#{value.to_s[0..10]}..." : value
    end
  end

  # Raised when the API returns an error response
  # Contains HTTP status code, response body, and headers for debugging
  #
  # @example Handling API errors
  #   begin
  #     results = client.check_individual(names: "Test")
  #   rescue DilisensePepClient::APIError => e
  #     puts "API error: #{e.message}"
  #     puts "Status: #{e.status}"
  #     puts "Retryable? #{e.retryable?}"
  #   end
  class APIError < Error
    attr_reader :status, :body, :headers

    def initialize(message, status: nil, body: nil, headers: {}, **options)
      @status = status
      @body = sanitize_body(body)
      @headers = sanitize_headers(headers)
      
      context = {
        status: status,
        response_size: body&.to_s&.length,
        endpoint: options[:endpoint]
      }.merge(options.fetch(:context, {}))
      
      error_code = determine_error_code(status)
      
      super(message, error_code: error_code, context: context, **options)
    end

    def retryable?
      case status
      when 429, 502, 503, 504 then true
      when 500..599 then true
      else false
      end
    end

    def client_error?
      status.to_i.between?(400, 499)
    end

    def server_error?
      status.to_i.between?(500, 599)
    end

    private

    def determine_error_code(status)
      case status
      when 400 then "BAD_REQUEST"
      when 401 then "UNAUTHORIZED"
      when 403 then "FORBIDDEN"
      when 404 then "NOT_FOUND"
      when 429 then "RATE_LIMITED"
      when 500 then "INTERNAL_SERVER_ERROR"
      when 502 then "BAD_GATEWAY"
      when 503 then "SERVICE_UNAVAILABLE"
      when 504 then "GATEWAY_TIMEOUT"
      else "API_ERROR"
      end
    end

    def sanitize_body(body)
      return nil unless body
      body_str = body.to_s
      return body_str if body_str.length <= 1000
      "#{body_str[0..1000]}... (truncated)"
    end

    def sanitize_headers(headers)
      return {} unless headers.is_a?(Hash)
      
      headers.transform_values do |value|
        case value.to_s.downcase
        when /authorization|api.?key|token|secret/
          "[REDACTED]"
        else
          value.to_s.length > 100 ? "#{value.to_s[0..100]}..." : value
        end
      end
    end
  end

  # Raised when there's a network problem (timeout, connection failure, etc.)
  # These errors are usually retryable after a delay
  #
  # @example Network timeout
  #   begin
  #     results = client.check_individual(names: "Test")
  #   rescue DilisensePepClient::NetworkError => e
  #     puts "Network problem: #{e.message}"
  #     # Usually safe to retry after a delay
  #   end
  class NetworkError < Error
    def initialize(message, network_error: nil, **options)
      context = {
        network_error_class: network_error&.class&.name,
        network_error_message: network_error&.message
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "NETWORK_ERROR", context: context, **options)
    end

    def retryable?
      true
    end
  end

  # Raised specifically for authentication failures (401 status)
  # Usually means the API key is invalid or has been revoked
  #
  # @example Invalid API key
  #   # This raises AuthenticationError for invalid API key
  #   DilisensePepClient.configure do |config|
  #     config.api_key = "invalid_key"
  #   end
  #   DilisensePepClient.check_individual(names: "Test")  # => AuthenticationError
  class AuthenticationError < APIError
    def initialize(message, **options)
      super(message, error_code: "AUTH_ERROR", **options)
    end

    def security_event?
      true
    end

    def retryable?
      false # Auth errors should not be retried automatically
    end
  end

  # Raised when input parameters fail validation
  # Contains details about which validation rules failed
  #
  # @example Invalid parameters
  #   # This raises ValidationError - can't use both parameters
  #   client.check_individual(names: "John", search_all: "John")
  #
  # @example Missing required parameters
  #   # This raises ValidationError - need at least one search param
  #   client.check_individual()
  class ValidationError < Error
    attr_reader :validation_errors

    def initialize(message, validation_errors: [], field: nil, **options)
      @validation_errors = Array(validation_errors)
      
      context = {
        field: field,
        validation_errors: @validation_errors,
        error_count: @validation_errors.size
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "VALIDATION_ERROR", context: context, **options)
    end

    def retryable?
      false # Validation errors require user intervention
    end
  end

  # Rate limiting errors
  class RateLimitError < APIError
    attr_reader :retry_after, :limit, :remaining

    def initialize(message, retry_after: nil, limit: nil, remaining: nil, **options)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining
      
      context = {
        retry_after: retry_after,
        rate_limit: limit,
        rate_remaining: remaining,
        reset_time: retry_after ? Time.now + retry_after : nil
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "RATE_LIMITED", context: context, **options)
    end

    def retryable?
      true
    end

    def suggested_retry_delay
      @retry_after || 60 # Default to 60 seconds if not specified
    end
  end

  # Timeout-related errors
  class TimeoutError < NetworkError
    attr_reader :timeout_duration

    def initialize(message, timeout_duration: nil, **options)
      @timeout_duration = timeout_duration
      
      context = {
        timeout_duration: timeout_duration,
        timeout_type: determine_timeout_type(message)
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "TIMEOUT_ERROR", context: context, **options)
    end

    def retryable?
      true
    end

    private

    def determine_timeout_type(message)
      case message.downcase
      when /connection/ then "connection_timeout"
      when /read/ then "read_timeout"
      when /write/ then "write_timeout"
      else "general_timeout"
      end
    end
  end

  # Circuit breaker errors (from our circuit breaker implementation)
  class CircuitBreakerError < Error
    attr_reader :service_name, :circuit_state, :next_attempt_time

    def initialize(message, service_name:, circuit_state:, next_attempt_time: nil, **options)
      @service_name = service_name
      @circuit_state = circuit_state
      @next_attempt_time = next_attempt_time
      
      context = {
        service_name: service_name,
        circuit_state: circuit_state,
        next_attempt_time: next_attempt_time
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "CIRCUIT_BREAKER_OPEN", context: context, **options)
    end

    def retryable?
      circuit_state == :half_open
    end

    def security_event?
      true # Circuit breaker events are significant for monitoring
    end
  end

  # Data processing errors
  class DataProcessingError < Error
    attr_reader :data_type, :processing_stage

    def initialize(message, data_type: nil, processing_stage: nil, **options)
      @data_type = data_type
      @processing_stage = processing_stage
      
      context = {
        data_type: data_type,
        processing_stage: processing_stage
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "DATA_PROCESSING_ERROR", context: context, **options)
    end
  end

  # Compliance and audit-related errors
  class ComplianceError < Error
    attr_reader :compliance_rule, :severity_level

    def initialize(message, compliance_rule:, severity_level: :medium, **options)
      @compliance_rule = compliance_rule
      @severity_level = severity_level
      
      context = {
        compliance_rule: compliance_rule,
        severity_level: severity_level,
        requires_escalation: severity_level == :critical
      }.merge(options.fetch(:context, {}))
      
      super(message, error_code: "COMPLIANCE_VIOLATION", context: context, **options)
    end

    def security_event?
      true
    end

    def critical?
      severity_level == :critical
    end
  end

  # Error factory for consistent error creation
  class ErrorFactory
    class << self
      def create_from_response(response, endpoint: nil, request_id: nil)
        case response.status
        when 401
          AuthenticationError.new(
            "API authentication failed",
            status: response.status,
            body: response.body,
            headers: response.headers,
            endpoint: endpoint,
            request_id: request_id
          )
        when 429
          retry_after = extract_retry_after(response.headers)
          RateLimitError.new(
            "API rate limit exceeded",
            status: response.status,
            body: response.body,
            headers: response.headers,
            retry_after: retry_after,
            endpoint: endpoint,
            request_id: request_id
          )
        when 400..499
          APIError.new(
            "Client error: #{response.status}",
            status: response.status,
            body: response.body,
            headers: response.headers,
            endpoint: endpoint,
            request_id: request_id
          )
        when 500..599
          APIError.new(
            "Server error: #{response.status}",
            status: response.status,
            body: response.body,
            headers: response.headers,
            endpoint: endpoint,
            request_id: request_id
          )
        else
          APIError.new(
            "Unexpected response: #{response.status}",
            status: response.status,
            body: response.body,
            headers: response.headers,
            endpoint: endpoint,
            request_id: request_id
          )
        end
      end

      def create_network_error(original_error, context: {})
        case original_error
        when ::Faraday::TimeoutError
          TimeoutError.new(
            "Request timeout",
            network_error: original_error,
            context: context
          )
        when ::Faraday::ConnectionFailed
          NetworkError.new(
            "Connection failed",
            network_error: original_error,
            context: context
          )
        else
          NetworkError.new(
            "Network error: #{original_error.class.name}",
            network_error: original_error,
            context: context
          )
        end
      end

      private

      def extract_retry_after(headers)
        retry_after = headers["retry-after"] || headers["Retry-After"]
        return nil unless retry_after
        
        # Handle both seconds and HTTP-date formats
        if retry_after.match?(/^\d+$/)
          retry_after.to_i
        else
          # Parse HTTP-date and calculate seconds until then
          begin
            Time.parse(retry_after) - Time.now
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end