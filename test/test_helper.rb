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
end