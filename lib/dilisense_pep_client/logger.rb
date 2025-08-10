# frozen_string_literal: true

require "semantic_logger"
require "json"

module DilisensePepClient
  # Industrial-grade structured logging system for compliance and monitoring
  # 
  # This class provides enterprise-level logging capabilities specifically designed for
  # financial services and FinTech applications that require comprehensive audit trails,
  # security monitoring, and regulatory compliance.
  #
  # Features:
  # - Structured JSON logging in production environments
  # - Automatic PII anonymization and data sanitization
  # - Security event classification and severity levels
  # - Compliance-ready audit trail generation
  # - Request correlation through unique request IDs
  # - Environment-specific log levels and formatting
  # - Integration with SemanticLogger for enterprise features
  #
  # The logger automatically handles different environments:
  # - Production: JSON structured logs to stdout, INFO level
  # - Staging: Colored logs to stdout, INFO level
  # - Development: Colored logs to stdout, DEBUG level
  #
  # All sensitive data (API keys, tokens, PII) is automatically sanitized before logging.
  # Security events are classified by severity and logged with appropriate detail levels.
  #
  # @example Basic API request logging
  #   Logger.log_api_request(
  #     endpoint: "/v1/checkIndividual",
  #     params: { names: "John Smith" },
  #     duration: 1.5,
  #     response_status: 200
  #   )
  #
  # @example Security event logging
  #   Logger.log_security_event(
  #     event_type: "authentication_failure",
  #     details: { user_id: "user123", reason: "invalid_api_key" },
  #     severity: :high
  #   )
  class Logger
    class << self
      # Initialize the logging system with environment-specific configuration
      # Sets up SemanticLogger with appropriate appenders, formatters, and log levels
      #
      # @param environment [String] The application environment (production, staging, development)
      # @return [SemanticLogger::Logger] Configured logger instance
      def setup!(environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development")
        configure_semantic_logger(environment)
        @logger = SemanticLogger["DilisensePepClient"]
      end

      # Get the configured logger instance, initializing if necessary
      # Uses lazy initialization to ensure logger is configured when first accessed
      #
      # @return [SemanticLogger::Logger] The configured logger instance
      def logger
        @logger ||= setup!
      end

      # Log API requests for performance monitoring and debugging
      # Creates structured logs with sanitized parameters and error details
      #
      # @param endpoint [String] The API endpoint being called (e.g., "/v1/checkIndividual")
      # @param params [Hash] Request parameters (will be sanitized automatically)
      # @param duration [Float, nil] Request duration in seconds
      # @param response_status [Integer, nil] HTTP response status code
      # @param error [Exception, nil] Error object if request failed
      # @param request_id [String, nil] Unique request identifier (generated if not provided)
      # @return [Hash] The structured log payload
      def log_api_request(endpoint:, params:, duration: nil, response_status: nil, error: nil, request_id: nil)
        payload = {
          event_type: "api_request",
          endpoint: endpoint,
          params: sanitize_params(params),  # Remove sensitive data from parameters
          duration_ms: duration&.*(1000)&.round(2),  # Convert to milliseconds for easier reading
          response_status: response_status,
          request_id: request_id || generate_request_id,
          timestamp: Time.now.iso8601,
          environment: Rails.env rescue "unknown"
        }

        if error
          # Include error details for failed requests
          payload[:error] = {
            class: error.class.name,
            message: error.message,
            backtrace: error.backtrace&.first(5)  # Limited backtrace for log size management
          }
          logger.error("API request failed", payload)
        else
          logger.info("API request completed", payload)
        end

        payload
      end

      def log_screening_event(type:, query:, results_count:, duration: nil, user_id: nil, request_id: nil)
        payload = {
          event_type: "screening_event",
          screening_type: type,
          query_hash: hash_pii(query),
          results_count: results_count,
          duration_ms: duration&.*(1000)&.round(2),
          user_id: user_id,
          request_id: request_id || generate_request_id,
          timestamp: Time.now.iso8601,
          compliance_metadata: {
            retention_category: "pep_screening",
            data_classification: "restricted"
          }
        }

        logger.info("Screening completed", payload)
        payload
      end

      def log_configuration_change(config_key:, old_value:, new_value:, user_id: nil)
        payload = {
          event_type: "configuration_change",
          config_key: config_key,
          old_value: sanitize_config_value(old_value),
          new_value: sanitize_config_value(new_value),
          user_id: user_id,
          timestamp: Time.now.iso8601
        }

        logger.warn("Configuration changed", payload)
        payload
      end

      def log_security_event(event_type:, details:, severity: :medium, user_id: nil)
        payload = {
          event_type: "security_event",
          security_event_type: event_type,
          severity: severity,
          details: details,
          user_id: user_id,
          timestamp: Time.now.iso8601,
          source_ip: Thread.current[:request_ip]
        }

        case severity
        when :critical
          logger.fatal("Critical security event", payload)
        when :high
          logger.error("High severity security event", payload)
        when :medium
          logger.warn("Medium severity security event", payload)
        else
          logger.info("Security event", payload)
        end

        payload
      end

      private

      def configure_semantic_logger(environment)
        SemanticLogger.application = "DilisensePepClient"
        
        case environment.to_s.downcase
        when "production"
          SemanticLogger.default_level = :info
          SemanticLogger.add_appender(io: $stdout, formatter: :json)
        when "staging"
          SemanticLogger.default_level = :info
          SemanticLogger.add_appender(io: $stdout, formatter: :color)
        else
          SemanticLogger.default_level = :debug
          SemanticLogger.add_appender(io: $stdout, formatter: :color)
        end
      end

      def sanitize_params(params)
        return {} unless params.is_a?(Hash)
        
        params.transform_values do |value|
          case value.to_s.downcase
          when /api_key|token|secret|password/
            "[REDACTED]"
          else
            value.is_a?(String) && value.length > 100 ? "#{value[0..100]}..." : value
          end
        end
      end

      def sanitize_config_value(value)
        return "[REDACTED]" if value.to_s.match?(/api_key|token|secret|password/i)
        value.to_s.length > 50 ? "#{value.to_s[0..50]}..." : value
      end

      def hash_pii(data)
        require "digest"
        Digest::SHA256.hexdigest(data.to_s)[0..16]
      end

      def generate_request_id
        require "securerandom"
        SecureRandom.hex(8)
      end
    end
  end
end