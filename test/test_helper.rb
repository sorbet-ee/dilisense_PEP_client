# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "dotenv/load"

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "minitest/autorun"
require "dilisense_pep_client"

class Minitest::Test
  def setup
    DilisensePepClient.reset!
  end

  def teardown
    # Add delay between API tests to avoid rate limits
    if self.class.name.include?("Integration") || self.class.name.include?("Entity") || self.class.name.include?("Fuzzy")
      sleep 2
    end
  end
end