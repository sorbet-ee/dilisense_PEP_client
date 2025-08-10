# frozen_string_literal: true

require_relative "dilisense_pep_client/version"
require_relative "dilisense_pep_client/configuration"
require_relative "dilisense_pep_client/errors"
require_relative "dilisense_pep_client/client"

module DilisensePepClient
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def client
      @client ||= Client.new
    end

    def check_individual(names: nil, search_all: nil, dob: nil, gender: nil, fuzzy_search: nil, includes: nil)
      client.check_individual(names: names, search_all: search_all, dob: dob, gender: gender, fuzzy_search: fuzzy_search, includes: includes)
    end

    def check_entity(params = {})
      client.check_entity(params)
    end

    def reset!
      @configuration = nil
      @client = nil
    end
  end
end