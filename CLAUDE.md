# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem client library for the Dilisense Screening API, specifically for PEP (Politically Exposed Persons) screening. The gem is owned by Sorbeet Payments OU and licensed under MIT.

## Development Setup

```bash
# Install dependencies
bundle install

# Copy environment file and add your API key
cp .env.example .env
# Edit .env and add your Dilisense API key
```

## Development Commands

```bash
# Run tests
bundle exec rake test

# Run linter
bundle exec rubocop

# Run both tests and linting
bundle exec rake ci

# Build gem
gem build dilisense_pep_client.gemspec

# Console for testing
bundle console
```

## Usage

```ruby
require 'dilisense_pep_client'

# Configure with API key (or set DILISENSE_API_KEY environment variable)
DilisensePepClient.configure do |config|
  config.api_key = 'your_api_key'
end

# Check individual - returns array with one element per unique person
result = DilisensePepClient.check_individual(
  names: "Mari Kask",
  dob: "15/03/1985",
  gender: "female"
)
# => [] (empty array if no matches)

result = DilisensePepClient.check_individual(names: "Donald Trump")
# => [
#   {
#     name: "Donald Trump Jr.",
#     source_type: "PEP", 
#     pep_type: "RELATIVES_AND_CLOSE_ASSOCIATES",
#     sources: ["dilisense_pep"],
#     total_records: 1
#   },
#   {
#     name: "Donald Trump",
#     source_type: "PEP",
#     pep_type: "POLITICIAN", 
#     sources: ["dilisense_pep"],
#     total_records: 2
#   }
# ]

# Check entity (still uses params hash)
result = DilisensePepClient.check_entity(names: "ACME Corp")
```

## Response Format

The `check_individual` method returns an **array** where each element represents a unique person:

```ruby
[
  {
    name: "Person Name",              # Primary name
    source_type: "PEP",              # PEP, SANCTION, CRIMINAL
    pep_type: "POLITICIAN",          # Only for PEP records
    gender: "MALE",                  # MALE, FEMALE, UNKNOWN
    date_of_birth: ["07/10/1952"],   # Array of DOBs
    citizenship: ["RU"],             # Array of citizenships
    sources: ["source1", "source2"], # All sources where found
    total_records: 16,               # Number of raw records
    raw_records: [...]               # All original API records
  }
]
```

## Implementation Notes

- API key authentication using `x-api-key` header
- GET requests with query parameters
- JSON responses with timestamp, total_hits, and found_records
- Error handling for 400, 401, 403, 500 status codes
- Uses Faraday for HTTP requests
- Minimal dependencies (only Faraday)