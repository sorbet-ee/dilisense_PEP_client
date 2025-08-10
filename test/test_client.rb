# frozen_string_literal: true

require_relative "test_helper"

class TestClient < Minitest::Test
  def setup
    super
    ENV["DILISENSE_API_KEY"] = "test_api_key"
    DilisensePepClient.reset!
  end

  def test_client_requires_api_key
    puts "\n=== Testing: API Key Validation ==="
    
    ENV["DILISENSE_API_KEY"] = ""
    DilisensePepClient.reset!

    error = assert_raises(DilisensePepClient::ConfigurationError) do
      DilisensePepClient::Client.new
    end

    puts "Result: ✓ Correctly rejected missing API key"
    puts "Error: #{error.message}"
    
    assert_equal "API key is required", error.message
  end

  def test_check_individual_validates_params
    puts "\n=== Testing: Parameter Validation ==="
    
    client = DilisensePepClient::Client.new

    puts "Testing conflicting parameters (names + search_all)..."
    error = assert_raises(DilisensePepClient::ValidationError) do
      client.check_individual(names: "John", search_all: "John")
    end
    puts "Result: ✓ Correctly rejected conflicting parameters"
    puts "Error: #{error.message}"
    assert_equal "Cannot use both search_all and names parameters", error.message

    puts "\nTesting missing parameters..."
    error2 = assert_raises(DilisensePepClient::ValidationError) do
      client.check_individual
    end
    puts "Result: ✓ Correctly rejected missing parameters"
    puts "Error: #{error2.message}"
    assert_equal "Either search_all or names parameter is required", error2.message
  end

  def test_check_individual_returns_empty_array_format
    name = "NonExistentPerson"
    puts "\n=== Testing: Array Format (mocked): #{name} ==="
    
    client = DilisensePepClient::Client.new
    
    # Mock the get_request to return empty response
    def client.get_request(endpoint, params)
      process_response_to_array({"total_hits" => 0, "found_records" => []})
    end
    
    result = client.check_individual(names: name)
    
    puts "People found: #{result.length}"
    if result.empty?
      puts "Result: ✓ Empty array returned for no matches"
    else
      puts "Result: ✗ Unexpected matches found"
    end
    
    assert_kind_of Array, result
    assert_equal 0, result.length
  end

  private

  def valid_api_key?
    ENV["DILISENSE_API_KEY"] && 
    ENV["DILISENSE_API_KEY"] != "test_api_key" && 
    !ENV["DILISENSE_API_KEY"].empty?
  end

  def test_check_entity_validates_params
    puts "\n=== Testing: Entity Parameter Validation ==="
    
    client = DilisensePepClient::Client.new

    puts "Testing entity conflicting parameters..."
    error = assert_raises(DilisensePepClient::ValidationError) do
      client.check_entity(names: "ACME", search_all: "ACME")
    end
    puts "Result: ✓ Entity validation working correctly"
    puts "Error: #{error.message}"

    error = assert_raises(DilisensePepClient::ValidationError) do
      client.check_entity({})
    end
    
    assert_equal "Cannot use both search_all and names parameters", error.message
    assert_equal "Either search_all or names parameter is required", error.message
  end
end