# frozen_string_literal: true

require "concurrent-ruby"

module DilisensePepClient
  # Comprehensive metrics collection and monitoring system for FinTech operations
  # 
  # This class provides enterprise-grade metrics collection specifically designed for
  # financial services applications that require detailed operational monitoring,
  # performance tracking, and regulatory compliance reporting.
  #
  # The metrics system supports four fundamental metric types:
  # - Counters: Ever-increasing values (e.g., total requests, errors)
  # - Gauges: Values that can increase or decrease (e.g., active connections, memory usage)
  # - Histograms: Distribution of values over time (e.g., response times, request sizes)
  # - Timers: Specialized histograms for measuring operation duration
  #
  # Features:
  # - Thread-safe concurrent operations using concurrent-ruby
  # - FinTech-specific metric categories (screening, compliance, security)
  # - Business metrics for PEP screening operations
  # - Prometheus export format for monitoring integration
  # - Memory-efficient histogram storage with automatic value rotation
  # - Comprehensive tagging system for metric dimensions
  # - Built-in percentile calculations (P50, P95, P99)
  # - Security and compliance event tracking
  # - Circuit breaker metrics integration
  #
  # @example Basic counter usage
  #   metrics = Metrics.new
  #   metrics.increment_counter("api_requests", tags: { endpoint: "/v1/check" })
  #
  # @example Timing operations
  #   result = metrics.time_operation("database_query") do
  #     database.execute_query(sql)
  #   end
  #
  # @example Recording screening events
  #   metrics.record_screening_request(
  #     type: "individual",
  #     search_terms_count: 2,
  #     user_id: "user123"
  #   )
  class Metrics
    # Standard metric types supported by the system
    # Each type has specific behaviors and use cases for monitoring
    METRIC_TYPES = {
      counter: :counter,        # Monotonically increasing values
      gauge: :gauge,           # Values that can increase or decrease
      histogram: :histogram,   # Distribution of values with percentiles
      timer: :timer           # Specialized histogram for timing operations
    }.freeze

    # FinTech-specific metric categories for organized monitoring
    # Each category groups related metrics for easier analysis and alerting
    CATEGORIES = {
      screening: "screening",      # PEP/sanctions screening operations
      performance: "performance",  # Response times, throughput, resource usage
      security: "security",       # Authentication, authorization, security events
      compliance: "compliance",   # Regulatory compliance, audit events
      reliability: "reliability", # Circuit breakers, failures, retries
      business: "business"        # Business KPIs, user activity, revenue metrics
    }.freeze

    # Initialize a new metrics collection instance
    #
    # @param service_name [String] Name of the service for metric prefixing (default: "dilisense_pep_client")
    def initialize(service_name: "dilisense_pep_client")
      @service_name = service_name
      @metrics = Concurrent::Map.new  # Thread-safe metric storage
      @start_time = Time.now  # Track service uptime
      @mutex = Mutex.new  # Synchronize metric creation operations
    end

    # Increment a counter metric by specified value
    # Counter metrics track monotonically increasing values like total requests, errors, or events
    #
    # @param name [String, Symbol] Name of the counter metric
    # @param value [Integer] Value to increment by (default: 1)
    # @param tags [Hash] Tag dimensions for the metric (e.g., { endpoint: "/api/v1" })
    # @param category [Symbol] Metric category for organization (default: :screening)
    #
    # @example Track API requests
    #   increment_counter("api_requests", tags: { endpoint: "/v1/check", method: "POST" })
    #
    # @example Track errors with multiple increments
    #   increment_counter("errors_total", value: 5, category: :reliability)
    def increment_counter(name, value: 1, tags: {}, category: :screening)
      metric_name = build_metric_name(name, category)
      metric = get_or_create_metric(metric_name, :counter, tags)
      metric[:value].add(value)  # Thread-safe atomic increment
      metric[:last_updated] = Time.now

      log_metric_update(:counter, metric_name, value, tags)
    end

    def decrement_counter(name, value: 1, tags: {}, category: :screening)
      increment_counter(name, value: -value, tags: tags, category: category)
    end

    # Gauge metrics - values that can go up or down
    def set_gauge(name, value, tags: {}, category: :performance)
      metric_name = build_metric_name(name, category)
      metric = get_or_create_metric(metric_name, :gauge, tags)
      metric[:value].value = value
      metric[:last_updated] = Time.now

      log_metric_update(:gauge, metric_name, value, tags)
    end

    def increment_gauge(name, value: 1, tags: {}, category: :performance)
      metric_name = build_metric_name(name, category)
      metric = get_or_create_metric(metric_name, :gauge, tags)
      new_value = metric[:value].increment(value)
      metric[:last_updated] = Time.now

      log_metric_update(:gauge, metric_name, new_value, tags)
      new_value
    end

    def decrement_gauge(name, value: 1, tags: {}, category: :performance)
      increment_gauge(name, value: -value, tags: tags, category: category)
    end

    # Histogram metrics - distribution of values
    def record_histogram(name, value, tags: {}, category: :performance)
      metric_name = build_metric_name(name, category)
      metric = get_or_create_metric(metric_name, :histogram, tags)
      
      histogram_data = metric[:histogram_data]
      histogram_data[:count].increment
      histogram_data[:sum].add(value)
      histogram_data[:values] << value
      
      # Keep only last 1000 values to prevent memory issues
      if histogram_data[:values].size > 1000
        histogram_data[:values].shift(histogram_data[:values].size - 1000)
      end
      
      metric[:last_updated] = Time.now
      update_histogram_stats(metric, value)

      log_metric_update(:histogram, metric_name, value, tags)
    end

    # Timer metrics - measure duration of operations
    def time_operation(name, tags: {}, category: :performance, &block)
      start_time = Time.now
      
      begin
        result = block.call
        duration = (Time.now - start_time) * 1000 # Convert to milliseconds
        record_histogram("#{name}_duration_ms", duration, tags: tags, category: category)
        increment_counter("#{name}_success_total", tags: tags, category: category)
        
        result
      rescue => error
        duration = (Time.now - start_time) * 1000
        record_histogram("#{name}_duration_ms", duration, tags: tags.merge(status: "error"), category: category)
        increment_counter("#{name}_error_total", tags: tags.merge(error_type: error.class.name), category: category)
        
        raise
      end
    end

    # Business metrics specific to PEP screening
    def record_screening_request(type:, search_terms_count: 1, user_id: nil)
      tags = { 
        screening_type: type, 
        terms_count: search_terms_count,
        user_id: user_id ? "present" : "absent"
      }
      
      increment_counter("screening_requests_total", tags: tags, category: :business)
      set_gauge("active_screening_sessions", get_active_sessions_count, category: :business)
    end

    def record_screening_response(
      type:, 
      records_found:, 
      processing_time_ms:, 
      data_sources: [], 
      cache_hit: false
    )
      tags = { 
        screening_type: type,
        records_found: records_found > 0 ? "found" : "none",
        cache_status: cache_hit ? "hit" : "miss"
      }
      
      increment_counter("screening_responses_total", tags: tags, category: :business)
      record_histogram("screening_processing_time_ms", processing_time_ms, tags: tags, category: :performance)
      
      if records_found > 0
        record_histogram("screening_records_found", records_found, tags: tags, category: :business)
        increment_counter("potential_matches_total", value: records_found, tags: tags, category: :compliance)
      end
      
      data_sources.each do |source|
        increment_counter("data_source_usage_total", tags: tags.merge(source: source), category: :business)
      end
    end

    def record_api_call(endpoint:, status_code:, duration_ms:, response_size: nil)
      tags = { 
        endpoint: endpoint,
        status_code: status_code,
        status_class: "#{status_code.to_s[0]}xx"
      }
      
      increment_counter("api_requests_total", tags: tags, category: :performance)
      record_histogram("api_duration_ms", duration_ms, tags: tags, category: :performance)
      
      if response_size
        record_histogram("api_response_size_bytes", response_size, tags: tags, category: :performance)
      end
      
      if status_code >= 400
        increment_counter("api_errors_total", tags: tags, category: :reliability)
      end
    end

    def record_security_event(event_type:, severity:, user_id: nil)
      tags = { 
        event_type: event_type,
        severity: severity,
        user_present: user_id ? "yes" : "no"
      }
      
      increment_counter("security_events_total", tags: tags, category: :security)
      
      if severity == :critical
        increment_counter("critical_security_events_total", tags: tags, category: :security)
      end
    end

    def record_compliance_event(framework:, event_type:, status:)
      tags = { 
        framework: framework,
        event_type: event_type,
        status: status
      }
      
      increment_counter("compliance_events_total", tags: tags, category: :compliance)
      
      if status == "violation"
        increment_counter("compliance_violations_total", tags: tags, category: :compliance)
      end
    end

    def record_circuit_breaker_event(service:, state:, failure_count: 0)
      tags = { service: service, state: state }
      
      increment_counter("circuit_breaker_events_total", tags: tags, category: :reliability)
      set_gauge("circuit_breaker_failure_count", failure_count, tags: tags, category: :reliability)
      
      if state == "open"
        increment_counter("circuit_breaker_trips_total", tags: tags, category: :reliability)
      end
    end

    # Retrieve metrics data
    def get_metric(name, category: nil)
      metric_name = category ? build_metric_name(name, category) : name
      metric = @metrics[metric_name]
      
      return nil unless metric
      
      case metric[:type]
      when :counter, :gauge
        {
          name: metric_name,
          type: metric[:type],
          value: metric[:value].value,
          tags: metric[:tags],
          last_updated: metric[:last_updated]
        }
      when :histogram
        histogram_data = metric[:histogram_data]
        {
          name: metric_name,
          type: metric[:type],
          count: histogram_data[:count].value,
          sum: histogram_data[:sum].value,
          mean: calculate_mean(metric),
          min: metric[:min],
          max: metric[:max],
          p50: calculate_percentile(metric, 0.5),
          p95: calculate_percentile(metric, 0.95),
          p99: calculate_percentile(metric, 0.99),
          tags: metric[:tags],
          last_updated: metric[:last_updated]
        }
      end
    end

    def get_all_metrics(category: nil)
      metrics_data = {}
      
      @metrics.each do |name, metric|
        next if category && !name.include?(CATEGORIES[category])
        
        metrics_data[name] = get_metric(name)
      end
      
      metrics_data
    end

    def get_summary
      {
        service_name: @service_name,
        uptime_seconds: Time.now - @start_time,
        total_metrics: @metrics.size,
        categories: get_metrics_by_category,
        last_updated: @metrics.values.map { |m| m[:last_updated] }.max,
        system_info: {
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM,
          process_id: Process.pid,
          memory_usage: get_memory_usage
        }
      }
    end

    def export_prometheus_format
      output = []
      
      @metrics.each do |name, metric|
        case metric[:type]
        when :counter
          output << "# TYPE #{name} counter"
          output << format_prometheus_line(name, metric[:value].value, metric[:tags])
        when :gauge
          output << "# TYPE #{name} gauge"
          output << format_prometheus_line(name, metric[:value].value, metric[:tags])
        when :histogram
          output << "# TYPE #{name} histogram"
          histogram_data = metric[:histogram_data]
          tags = metric[:tags]
          
          output << format_prometheus_line("#{name}_count", histogram_data[:count].value, tags)
          output << format_prometheus_line("#{name}_sum", histogram_data[:sum].value, tags)
          
          [0.5, 0.95, 0.99].each do |quantile|
            percentile_tags = tags.merge(quantile: quantile)
            output << format_prometheus_line("#{name}_quantile", calculate_percentile(metric, quantile), percentile_tags)
          end
        end
      end
      
      output.join("\n")
    end

    def reset_metrics!
      @mutex.synchronize do
        @metrics.clear
        Logger.logger.info("Metrics reset", service_name: @service_name)
      end
    end

    def reset_metric(name, category: nil)
      metric_name = category ? build_metric_name(name, category) : name
      @metrics.delete(metric_name)
    end

    private

    def build_metric_name(name, category)
      category_prefix = CATEGORIES[category] || category.to_s
      "#{@service_name}_#{category_prefix}_#{name}".gsub(/[^a-zA-Z0-9_]/, "_")
    end

    def get_or_create_metric(name, type, tags)
      @metrics.fetch(name) do
        @mutex.synchronize do
          @metrics.fetch(name) do
            @metrics[name] = create_metric(type, tags)
          end
        end
      end
    end

    def create_metric(type, tags)
      base_metric = {
        type: type,
        tags: tags,
        created_at: Time.now,
        last_updated: Time.now
      }

      case type
      when :counter, :gauge
        base_metric[:value] = Concurrent::AtomicFixnum.new(0)
      when :histogram
        base_metric.merge!(
          histogram_data: {
            count: Concurrent::AtomicFixnum.new(0),
            sum: Concurrent::AtomicFixnum.new(0),
            values: Concurrent::Array.new
          },
          min: Float::INFINITY,
          max: -Float::INFINITY
        )
      end

      base_metric
    end

    def update_histogram_stats(metric, value)
      metric[:min] = [metric[:min], value].min
      metric[:max] = [metric[:max], value].max
    end

    def calculate_mean(metric)
      histogram_data = metric[:histogram_data]
      count = histogram_data[:count].value
      return 0 if count == 0
      
      histogram_data[:sum].value.to_f / count
    end

    def calculate_percentile(metric, percentile)
      values = metric[:histogram_data][:values].to_a.sort
      return 0 if values.empty?
      
      index = (percentile * (values.length - 1)).round
      values[index] || 0
    end

    def get_active_sessions_count
      # This would be implemented based on your session tracking
      # For now, return a placeholder
      1
    end

    def get_metrics_by_category
      categories = {}
      
      @metrics.each do |name, _|
        CATEGORIES.each do |category_key, category_name|
          if name.include?(category_name)
            categories[category_key] ||= 0
            categories[category_key] += 1
            break
          end
        end
      end
      
      categories
    end

    def get_memory_usage
      begin
        # Try to get memory usage (works on most Unix systems)
        `ps -o rss= -p #{Process.pid}`.strip.to_i * 1024
      rescue
        0
      end
    end

    def format_prometheus_line(name, value, tags)
      if tags.empty?
        "#{name} #{value}"
      else
        tag_string = tags.map { |k, v| "#{k}=\"#{v}\"" }.join(",")
        "#{name}{#{tag_string}} #{value}"
      end
    end

    def log_metric_update(type, name, value, tags)
      return unless Logger.respond_to?(:logger)
      
      Logger.logger.debug("Metric updated", {
        metric_type: type,
        metric_name: name,
        value: value,
        tags: tags,
        service: @service_name
      })
    end
  end

  # Global metrics registry
  class MetricsRegistry
    def self.instance
      @instance ||= new
    end

    def initialize
      @metrics = Metrics.new
    end

    def method_missing(method_name, *args, **kwargs, &block)
      if @metrics.respond_to?(method_name)
        @metrics.send(method_name, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @metrics.respond_to?(method_name, include_private) || super
    end
  end
end