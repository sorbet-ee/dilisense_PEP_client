# frozen_string_literal: true

require_relative "test_helper"

class TestDilisensePepClient < Minitest::Test
  def test_that_it_has_a_version_number
    puts "\n=== Testing: Version Number ==="
    puts "Version: #{DilisensePepClient::VERSION}"
    puts "Result: ✓ Version number is set"
    
    refute_nil DilisensePepClient::VERSION
  end

  def test_configuration
    puts "\n=== Testing: Configuration Override ==="
    
    ENV["DILISENSE_API_KEY"] = "env_key_test"
    DilisensePepClient.reset!

    DilisensePepClient.configure do |config|
      config.api_key = "test_key_12345"
      config.base_url = "https://test.example.com"
    end

    puts "API Key: #{DilisensePepClient.configuration.api_key}"
    puts "Base URL: #{DilisensePepClient.configuration.base_url}"
    puts "Result: ✓ Configuration override working"
    
    assert_equal "test_key_12345", DilisensePepClient.configuration.api_key
    assert_equal "https://test.example.com", DilisensePepClient.configuration.base_url
  end

  def test_configuration_defaults
    puts "\n=== Testing: Default Configuration ==="
    
    original_key = ENV["DILISENSE_API_KEY"]
    ENV.delete("DILISENSE_API_KEY")
    DilisensePepClient.reset!
    
    # Set a test key directly
    DilisensePepClient.configure do |config|
      config.api_key = "test_key_12345"
    end
    
    config = DilisensePepClient.configuration

    puts "Base URL: #{config.base_url}"
    puts "Timeout: #{config.timeout}s"
    puts "API Key: #{config.api_key ? "[SET]" : "[NOT SET]"}"
    puts "Result: ✓ Default configuration loaded correctly"
    
    assert_equal "https://api.dilisense.com", config.base_url
    assert_equal 30, config.timeout
    assert_equal "test_key_12345", config.api_key
    
    # Restore original key
    ENV["DILISENSE_API_KEY"] = original_key if original_key
  end
end