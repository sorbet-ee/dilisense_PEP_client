# frozen_string_literal: true

require_relative "test_helper"

class TestFuzzy < Minitest::Test
  def setup
    super
    DilisensePepClient.reset!
  end

  def test_fuzzy_search_vladimer_putin
    name = "Vladimer Putin"  # Misspelled intentionally
    puts "\n=== Testing fuzzy search: #{name} (misspelled) ==="
    
    result = DilisensePepClient.check_individual(
      names: name,
      fuzzy_search: 1
    )
    
    puts "People found: #{result.length}"
    
    if result.length > 0
      puts "\nFuzzy search found matches:"
      result.first(5).each_with_index do |person, i|
        puts "  #{i + 1}. #{person[:name]} (#{person[:source_type]})"
      end
      puts "  ... (showing first 5 of #{result.length} people)" if result.length > 5
    else
      puts "No fuzzy matches found"
    end
    
    assert_kind_of Array, result
    assert result.length > 0, "Should find fuzzy matches for misspelled Putin"
  end

  def test_fuzzy_search_distance_2
    name = "Vladamir Putin"  # More misspellings
    puts "\n=== Testing fuzzy search distance 2: #{name} ==="
    
    result = DilisensePepClient.check_individual(
      names: name,
      fuzzy_search: 2
    )
    
    puts "People found: #{result.length}"
    
    if result.length > 0
      puts "\nFuzzy distance 2 matches:"
      result.first(3).each_with_index do |person, i|
        puts "  #{i + 1}. #{person[:name]} (#{person[:source_type]})"
      end
    else
      puts "No fuzzy matches found with distance 2"
    end
    
    assert_kind_of Array, result
  end

  def test_fuzzy_search_clean_name
    name = "John Smith Random"  # Should not match anything
    puts "\n=== Testing fuzzy search: #{name} (clean name) ==="
    
    result = DilisensePepClient.check_individual(
      names: name,
      fuzzy_search: 1
    )
    
    puts "People found: #{result.length}"
    
    if result.length > 0
      puts "\nUnexpected matches found:"
      result.first(3).each_with_index do |person, i|
        puts "  #{i + 1}. #{person[:name]} (#{person[:source_type]})"
      end
    else
      puts "No fuzzy matches found (expected for clean name)"
    end
    
    assert_kind_of Array, result
    assert_equal 0, result.length, "Should not find matches for random clean name"
  end

  private

end