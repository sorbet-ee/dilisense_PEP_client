# frozen_string_literal: true

require_relative "test_helper"

class TestIntegration < Minitest::Test
  def setup
    super
    DilisensePepClient.reset!
  end

  def test_vladimir_putin_name_only
    name = "Vladimir Putin"
    puts "\n=== Testing: #{name} (name only) ==="
    
    result = DilisensePepClient.check_individual(names: name)
    
    puts "People found: #{result.length}"
    
    result.each_with_index do |person, i|
      puts "\nPerson #{i + 1}:"
      puts "  Name: #{person[:name]}"
      puts "  Source Type: #{person[:source_type]}"
      puts "  PEP Type: #{person[:pep_type]}" if person[:pep_type]
      puts "  Gender: #{person[:gender]}" if person[:gender]
      puts "  DOB: #{person[:date_of_birth]&.first}" if person[:date_of_birth]
      puts "  Citizenship: #{person[:citizenship]&.join(', ')}" if person[:citizenship]
      puts "  Found in #{person[:total_records]} source(s): #{person[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No people found"
    end
    
    assert_kind_of Array, result
    
    if result.length > 0
      person = result.first
      assert person[:name]
      assert_includes ["PEP", "SANCTION"], person[:source_type]
    end
  end

  def test_donald_trump_with_gender
    name = "Donald Trump"
    gender = "male"
    puts "\n=== Testing: #{name} (with gender: #{gender}) ==="
    
    result = DilisensePepClient.check_individual(
      names: name,
      gender: gender
    )
    
    puts "People found: #{result.length}"
    
    result.each_with_index do |person, i|
      puts "\nPerson #{i + 1}:"
      puts "  Name: #{person[:name]}"
      puts "  Source Type: #{person[:source_type]}"
      puts "  PEP Type: #{person[:pep_type]}" if person[:pep_type]
      puts "  Gender: #{person[:gender]}" if person[:gender]
      puts "  DOB: #{person[:date_of_birth]&.first}" if person[:date_of_birth]
      puts "  Citizenship: #{person[:citizenship]&.join(', ')}" if person[:citizenship]
      puts "  Found in #{person[:total_records]} source(s): #{person[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No people found"
    end
    
    assert_kind_of Array, result
    
    if result.length > 0
      person = result.first
      assert person[:name]
      assert_includes ["PEP", "SANCTION"], person[:source_type]
    end
  end

  def test_angelos_kapsimanis_full_params
    name = "Angelos Kapsimanis"
    dob = "14/06/1982"
    gender = "male"
    puts "\n=== Testing: #{name} (full params: DOB=#{dob}, gender=#{gender}) ==="
    
    result = DilisensePepClient.check_individual(
      names: name,
      dob: dob,
      gender: gender
    )
    
    puts "People found: #{result.length}"
    
    result.each_with_index do |person, i|
      puts "\nPerson #{i + 1}:"
      puts "  Name: #{person[:name]}"
      puts "  Source Type: #{person[:source_type]}"
      puts "  PEP Type: #{person[:pep_type]}" if person[:pep_type]
      puts "  Gender: #{person[:gender]}" if person[:gender]
      puts "  DOB: #{person[:date_of_birth]&.first}" if person[:date_of_birth]
      puts "  Citizenship: #{person[:citizenship]&.join(', ')}" if person[:citizenship]
      puts "  Found in #{person[:total_records]} source(s): #{person[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No people found (clean record - good!)"
    end
    
    assert_kind_of Array, result
    assert_equal 0, result.length
  end

  def test_search_all_parameter
    query = "Vladimir Putin"
    puts "\n=== Testing search_all parameter: #{query} ==="
    
    result = DilisensePepClient.check_individual(search_all: query)
    
    puts "People found: #{result.length}"
    
    if result.length > 0
      puts "\nFirst person:"
      person = result.first
      puts "  Name: #{person[:name]}"
      puts "  Source Type: #{person[:source_type]}"
      puts "  PEP Type: #{person[:pep_type]}" if person[:pep_type]
      puts "  Found in #{person[:total_records]} source(s)"
    else
      puts "No people found"
    end
    
    assert_kind_of Array, result
  end


  private

end