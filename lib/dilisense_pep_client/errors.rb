# frozen_string_literal: true

module DilisensePepClient
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class APIError < Error
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class NetworkError < Error; end

  class AuthenticationError < APIError; end

  class ValidationError < APIError; end
end