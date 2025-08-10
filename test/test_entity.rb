# frozen_string_literal: true

require_relative "test_helper"

class TestEntity < Minitest::Test
  def setup
    super
    DilisensePepClient.reset!
  end

  def test_tesla
    name = "Tesla"
    puts "\n=== Testing Entity: #{name} ==="
    
    result = DilisensePepClient.check_entity(names: name)
    
    puts "Entities found: #{result.length}"
    
    result.each_with_index do |entity, i|
      puts "\nEntity #{i + 1}:"
      puts "  Name: #{entity[:name]}"
      puts "  Source Type: #{entity[:source_type]}"
      puts "  PEP Type: #{entity[:pep_type]}" if entity[:pep_type]
      puts "  Jurisdiction: #{entity[:jurisdiction]&.join(', ')}" if entity[:jurisdiction]
      puts "  Address: #{entity[:address]&.first}" if entity[:address]
      puts "  Found in #{entity[:total_records]} source(s): #{entity[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No entities found (clean record)"
    end
    
    assert_kind_of Array, result
  end

  def test_apple
    name = "Apple"
    puts "\n=== Testing Entity: #{name} ==="
    
    result = DilisensePepClient.check_entity(names: name)
    
    puts "Entities found: #{result.length}"
    
    result.each_with_index do |entity, i|
      puts "\nEntity #{i + 1}:"
      puts "  Name: #{entity[:name]}"
      puts "  Source Type: #{entity[:source_type]}"
      puts "  PEP Type: #{entity[:pep_type]}" if entity[:pep_type]
      puts "  Jurisdiction: #{entity[:jurisdiction]&.join(', ')}" if entity[:jurisdiction]
      puts "  Address: #{entity[:address]&.first}" if entity[:address]
      puts "  Found in #{entity[:total_records]} source(s): #{entity[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No entities found (clean record)"
    end
    
    assert_kind_of Array, result
  end

  def test_gazprom
    name = "Gazprom"
    puts "\n=== Testing Entity: #{name} ==="
    
    result = DilisensePepClient.check_entity(names: name)
    
    puts "Entities found: #{result.length}"
    
    result.each_with_index do |entity, i|
      puts "\nEntity #{i + 1}:"
      puts "  Name: #{entity[:name]}"
      puts "  Source Type: #{entity[:source_type]}"
      puts "  PEP Type: #{entity[:pep_type]}" if entity[:pep_type]
      puts "  Jurisdiction: #{entity[:jurisdiction]&.join(', ')}" if entity[:jurisdiction]
      puts "  Address: #{entity[:address]&.first}" if entity[:address]
      puts "  Sanction Details: #{entity[:sanction_details]&.first}" if entity[:sanction_details]
      puts "  Found in #{entity[:total_records]} source(s): #{entity[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No entities found"
    end
    
    assert_kind_of Array, result
    # Gazprom should likely be found in sanctions lists
    assert result.length > 0, "Expected to find Gazprom in sanctions lists"
  end

  def test_elbit_industries
    name = "Elbit Industries"
    puts "\n=== Testing Entity: #{name} ==="
    
    result = DilisensePepClient.check_entity(names: name)
    
    puts "Entities found: #{result.length}"
    
    result.each_with_index do |entity, i|
      puts "\nEntity #{i + 1}:"
      puts "  Name: #{entity[:name]}"
      puts "  Source Type: #{entity[:source_type]}"
      puts "  PEP Type: #{entity[:pep_type]}" if entity[:pep_type]
      puts "  Jurisdiction: #{entity[:jurisdiction]&.join(', ')}" if entity[:jurisdiction]
      puts "  Address: #{entity[:address]&.first}" if entity[:address]
      puts "  Found in #{entity[:total_records]} source(s): #{entity[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No entities found (clean record)"
    end
    
    assert_kind_of Array, result
  end

  def test_bank_rossiya
    name = "Bank Rossiya"
    puts "\n=== Testing Entity: #{name} ==="
    
    result = DilisensePepClient.check_entity(names: name)
    
    puts "Entities found: #{result.length}"
    
    result.each_with_index do |entity, i|
      puts "\nEntity #{i + 1}:"
      puts "  Name: #{entity[:name]}"
      puts "  Source Type: #{entity[:source_type]}"
      puts "  PEP Type: #{entity[:pep_type]}" if entity[:pep_type]
      puts "  Jurisdiction: #{entity[:jurisdiction]&.join(', ')}" if entity[:jurisdiction]
      puts "  Address: #{entity[:address]&.first}" if entity[:address]
      puts "  Sanction Details: #{entity[:sanction_details]&.first}" if entity[:sanction_details]
      puts "  Found in #{entity[:total_records]} source(s): #{entity[:sources].join(', ')}"
    end
    
    if result.empty?
      puts "No entities found"
    end
    
    assert_kind_of Array, result
    # Bank Rossiya should likely be found in sanctions lists
    assert result.length > 0, "Expected to find Bank Rossiya in sanctions lists"
  end

  private

end