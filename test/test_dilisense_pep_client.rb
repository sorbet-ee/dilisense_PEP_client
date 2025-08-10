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
    
    ENV["DILISENSE_API_KEY"] = "env_key"
    DilisensePepClient.reset!

    DilisensePepClient.configure do |config|
      config.api_key = "test_key"
      config.base_url = "https://test.example.com"
    end

    puts "API Key: #{DilisensePepClient.configuration.api_key}"
    puts "Base URL: #{DilisensePepClient.configuration.base_url}"
    puts "Result: ✓ Configuration override working"
    
    assert_equal "test_key", DilisensePepClient.configuration.api_key
    assert_equal "https://test.example.com", DilisensePepClient.configuration.base_url
  end

  def test_configuration_defaults
    puts "\n=== Testing: Default Configuration ==="
    
    ENV["DILISENSE_API_KEY"] = "test_key"
    DilisensePepClient.reset!
    
    config = DilisensePepClient.configuration

    puts "Base URL: #{config.base_url}"
    puts "Timeout: #{config.timeout}s"
    puts "API Key: #{config.api_key}"
    puts "Result: ✓ Default configuration loaded correctly"
    
    assert_equal "https://api.dilisense.com", config.base_url
    assert_equal 30, config.timeout
    assert_equal "test_key", config.api_key
  end
end