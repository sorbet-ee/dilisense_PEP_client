# frozen_string_literal: true

require "concurrent-ruby"

module DilisensePepClient
  # Circuit breaker implementation for API resilience and fault tolerance
  # 
  # This class implements the Circuit Breaker pattern to protect against cascading failures
  # when the Dilisense API becomes unavailable or starts returning errors frequently.
  # It prevents unnecessary load on a failing service by temporarily blocking requests
  # and allowing the service time to recover.
  #
  # States:
  # - CLOSED: Normal operation, requests pass through
  # - OPEN: Service is failing, all requests are blocked
  # - HALF_OPEN: Testing if service has recovered, limited requests allowed
  #
  # The circuit breaker automatically transitions between states based on:
  # - Failure threshold: Number of consecutive failures before opening
  # - Recovery timeout: Time to wait before attempting to recover
  # - Success criteria: Requirements to close the circuit after half-open
  #
  # Features:
  # - Thread-safe operation using concurrent-ruby primitives
  # - Configurable failure thresholds and recovery timeouts
  # - Timeout protection for individual requests
  # - Comprehensive metrics and logging
  # - Security event logging for monitoring
  #
  # @example Basic usage with default settings
  #   breaker = CircuitBreaker.new(service_name: "dilisense_api")
  #   result = breaker.call do
  #     # Make API request here
  #     api_client.get("/endpoint")
  #   end
  #
  # @example Custom configuration for high-availability requirements
  #   breaker = CircuitBreaker.new(
  #     service_name: "dilisense_api",
  #     failure_threshold: 3,     # Open after 3 failures
  #     recovery_timeout: 30,     # Try again after 30 seconds
  #     timeout: 15,              # Individual request timeout
  #     exceptions: [APIError, NetworkError]  # Only these errors count as failures
  #   )
  class CircuitBreaker
    # Exception raised when the circuit breaker is in the OPEN state
    # Indicates that requests are being blocked to protect the downstream service
    class CircuitOpenError < StandardError
      def initialize(service_name, next_attempt_time)
        super("Circuit breaker is OPEN for #{service_name}. Next attempt allowed at #{next_attempt_time}")
        @service_name = service_name
        @next_attempt_time = next_attempt_time
      end

      attr_reader :service_name, :next_attempt_time
    end

    # Valid circuit breaker states following the standard pattern
    STATES = %i[closed open half_open].freeze

    # Initialize a new circuit breaker with specified configuration
    #
    # @param service_name [String] Name of the protected service (for logging and metrics)
    # @param failure_threshold [Integer] Number of failures before opening the circuit (default: 5)
    # @param recovery_timeout [Integer] Seconds to wait before attempting recovery (default: 60)
    # @param timeout [Integer] Timeout for individual requests in seconds (default: 30)
    # @param exceptions [Array<Class>] Exception types that count as failures (default: [StandardError])
    def initialize(
      service_name:,
      failure_threshold: 5,
      recovery_timeout: 60,
      timeout: 30,
      exceptions: [StandardError]
    )
      @service_name = service_name
      @failure_threshold = failure_threshold
      @recovery_timeout = recovery_timeout
      @timeout = timeout
      @exceptions = exceptions
      
      # Initialize state - circuit starts in CLOSED (normal) state
      @state = :closed
      @failure_count = Concurrent::AtomicFixnum.new(0)  # Thread-safe failure counter
      @last_failure_time = Concurrent::AtomicReference.new  # Track when last failure occurred
      @next_attempt_time = Concurrent::AtomicReference.new  # When to allow next attempt after opening
      @success_count = Concurrent::AtomicFixnum.new(0)  # Track successful requests
      @mutex = Mutex.new  # Synchronize state transitions
    end

    # Execute a block of code with circuit breaker protection
    # This is the main method that wraps your API calls or other potentially failing operations
    #
    # @param block [Proc] The code to execute (typically an API call)
    # @return [Object] Result of the executed block
    # @raise [CircuitOpenError] When circuit is open and blocking requests
    # @raise [Exception] Any exception raised by the protected code
    #
    # @example Protect an API call
    #   result = circuit_breaker.call do
    #     http_client.get("/api/endpoint")
    #   end
    def call(&block)
      case state
      when :open
        # Circuit is open - check if enough time has passed to allow a test request
        check_if_half_open_allowed
        raise CircuitOpenError.new(@service_name, @next_attempt_time.value)
      when :half_open
        # Circuit is testing recovery - attempt the request and reset if successful
        attempt_reset(&block)
      when :closed
        # Circuit is closed - normal operation, execute the request
        execute(&block)
      end
    rescue *@exceptions => e
      # Catch configured exception types and record as failures
      record_failure(e)
      raise
    end

    def state
      @mutex.synchronize { @state }
    end

    def failure_count
      @failure_count.value
    end

    def success_count
      @success_count.value
    end

    def metrics
      {
        service_name: @service_name,
        state: state,
        failure_count: failure_count,
        success_count: success_count,
        failure_threshold: @failure_threshold,
        recovery_timeout: @recovery_timeout,
        last_failure_time: @last_failure_time.value,
        next_attempt_time: @next_attempt_time.value
      }
    end

    def reset!
      @mutex.synchronize do
        @state = :closed
        @failure_count.value = 0
        @success_count.value = 0
        @last_failure_time.value = nil
        @next_attempt_time.value = nil
      end
      
      Logger.logger.info("Circuit breaker reset", service_name: @service_name)
    end

    def force_open!
      @mutex.synchronize do
        @state = :open
        @next_attempt_time.value = Time.now + @recovery_timeout
      end
      
      Logger.logger.warn("Circuit breaker forced open", service_name: @service_name)
    end

    private

    def execute(&block)
      result = Concurrent::Promises.future(executor: :io) do
        block.call
      end.value!(@timeout)

      record_success
      result
    rescue Concurrent::TimeoutError
      record_failure(StandardError.new("Request timeout after #{@timeout} seconds"))
      raise NetworkError, "Request timeout after #{@timeout} seconds"
    end

    def attempt_reset(&block)
      result = execute(&block)
      reset_after_success
      result
    rescue *@exceptions => e
      trip_breaker
      raise e
    end

    def record_failure(error)
      @failure_count.increment
      @last_failure_time.value = Time.now
      
      Logger.log_security_event(
        event_type: "circuit_breaker_failure",
        details: {
          service_name: @service_name,
          error_class: error.class.name,
          error_message: error.message,
          failure_count: @failure_count.value
        },
        severity: @failure_count.value >= @failure_threshold ? :high : :medium
      )

      trip_breaker if @failure_count.value >= @failure_threshold
    end

    def record_success
      @success_count.increment
      
      if state == :half_open
        Logger.logger.info("Circuit breaker success in half-open state", 
                          service_name: @service_name, 
                          success_count: @success_count.value)
      end
    end

    def trip_breaker
      @mutex.synchronize do
        @state = :open
        @next_attempt_time.value = Time.now + @recovery_timeout
      end
      
      Logger.log_security_event(
        event_type: "circuit_breaker_opened",
        details: {
          service_name: @service_name,
          failure_count: @failure_count.value,
          next_attempt_time: @next_attempt_time.value
        },
        severity: :high
      )
    end

    def check_if_half_open_allowed
      return unless @next_attempt_time.value && Time.now >= @next_attempt_time.value
      
      @mutex.synchronize do
        if Time.now >= @next_attempt_time.value
          @state = :half_open
          Logger.logger.info("Circuit breaker entering half-open state", service_name: @service_name)
        end
      end
    end

    def reset_after_success
      @mutex.synchronize do
        @state = :closed
        @failure_count.value = 0
        @last_failure_time.value = nil
        @next_attempt_time.value = nil
      end
      
      Logger.logger.info("Circuit breaker reset to closed after success", service_name: @service_name)
    end
  end
end