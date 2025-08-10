# Makefile for dilisense_pep_client Ruby gem
# 
# This Makefile provides convenient commands for development, testing, and maintenance
# of the Dilisense PEP/sanctions screening Ruby client library.
#
# The gem includes both unit tests (no external dependencies) and integration tests
# that make real API calls to the Dilisense service. API key must be configured
# in .env file for integration tests to work properly.

.PHONY: test individual_test unit_test test_fuzzy entity_test install lint ci clean help

# Default target - show available commands
help:
	@echo "Dilisense PEP Client - Available Make Commands:"
	@echo ""
	@echo "Testing Commands:"
	@echo "  test           - Run all tests (unit + integration with 2-second delays)"
	@echo "  individual_test - Run individual screening tests with real API calls"
	@echo "  unit_test      - Run unit tests only (no external API calls required)"
	@echo "  test_fuzzy     - Run fuzzy search integration tests with real API calls"
	@echo "  entity_test    - Run entity screening tests with real API calls"
	@echo ""
	@echo "Development Commands:"
	@echo "  install        - Install Ruby gem dependencies via Bundler"
	@echo "  lint           - Run RuboCop code style linter and formatter"
	@echo "  ci             - Run continuous integration suite (tests + linting)"
	@echo "  clean          - Remove generated coverage reports and temporary files"
	@echo ""
	@echo "Requirements:"
	@echo "  - Ruby 2.7+ with Bundler installed"
	@echo "  - Valid Dilisense API key in .env file for integration tests"
	@echo "  - Internet connection for API-based tests"

# Install Ruby gem dependencies via Bundler
# This will install all gems specified in the Gemfile including development dependencies
install:
	@echo "Installing Ruby gem dependencies..."
	bundle install
	@echo "Dependencies installed successfully!"

# Run all tests with rate limit protection (2-second delays between tests)
# Includes both unit tests and integration tests with real API calls
test:
	@echo "Running comprehensive test suite with rate limiting..."
	bundle exec rake test

# Run individual screening integration tests with real API calls
# Tests person-based PEP screening functionality against live Dilisense API
individual_test:
	@echo "Running individual screening integration tests..."
	@echo "Testing names: Vladimir Putin, Xi Jinping, Joe Biden..."
	bundle exec ruby -Ilib:test test/test_integration.rb
	@echo "Individual screening tests completed!"

# Run unit tests only - no external API calls required
# These tests use mocks and stubs to verify internal logic without network dependencies
unit_test:
	@echo "Running unit tests (no API calls)..."
	bundle exec ruby -Ilib:test test/test_client.rb test/test_dilisense_pep_client.rb
	@echo "Unit tests completed!"

# Run fuzzy search integration tests with real API calls
# Tests fuzzy matching capabilities for names with variations and typos
test_fuzzy:
	@echo "Running fuzzy search integration tests..."
	@echo "Testing fuzzy matching for: Vladmir Putin (typo), Xi Jin Ping (spacing)..."
	bundle exec ruby -Ilib:test test/test_fuzzy.rb
	@echo "Fuzzy search tests completed!"

# Run entity screening integration tests with real API calls
# Tests company/organization screening against sanctions and watchlists
entity_test:
	@echo "Running entity screening integration tests..."
	@echo "Testing entities: Bank Rossiya, Gazprom, sanctioned organizations..."
	bundle exec ruby -Ilib:test test/test_entity.rb
	@echo "Entity screening tests completed!"

# Run RuboCop linter to check code style and formatting
# Enforces Ruby style guide and identifies potential issues
lint:
	@echo "Running RuboCop code style linter..."
	bundle exec rubocop
	@echo "Linting completed!"

# Run continuous integration suite (tests + linting)
# Comprehensive check suitable for CI/CD pipelines
ci:
	@echo "Running CI suite (tests + linting)..."
	bundle exec rake ci
	@echo "CI suite completed!"

# Clean generated files and coverage reports
# Removes temporary files created during testing and development
clean:
	@echo "Cleaning generated files..."
	rm -rf coverage/
	rm -rf tmp/
	@echo "Cleanup completed!"