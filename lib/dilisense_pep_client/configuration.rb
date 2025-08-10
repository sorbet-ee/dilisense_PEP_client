# frozen_string_literal: true

module DilisensePepClient
  # Simple configuration management
  # Stores basic settings needed for API communication
  class Configuration
    attr_accessor :api_key, :base_url, :timeout

    def initialize
      @base_url = "https://api.dilisense.com"
      @timeout = 30
      @api_key = ENV["DILISENSE_API_KEY"]
    end
  end
end