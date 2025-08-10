# Makefile for dilisense_pep_client

.PHONY: test individual_test unit_test test_fuzzy install lint ci clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  test           - Run all tests (unit + integration)"
	@echo "  individual_test - Run only integration tests with real API calls"
	@echo "  unit_test      - Run only unit tests (no API calls)"
	@echo "  test_fuzzy     - Run fuzzy search tests with real API calls"
	@echo "  install        - Install dependencies"
	@echo "  lint           - Run RuboCop linter"
	@echo "  ci             - Run tests and linter"
	@echo "  clean          - Clean coverage reports"

# Install dependencies
install:
	bundle install

# Run all tests
test:
	bundle exec rake test

# Run only integration tests (with real API calls)
individual_test:
	bundle exec ruby -Ilib:test test/test_integration.rb

# Run only unit tests (no API calls)
unit_test:
	bundle exec ruby -Ilib:test test/test_client.rb test/test_dilisense_pep_client.rb

# Run fuzzy search tests (with real API calls)
test_fuzzy:
	bundle exec ruby -Ilib:test test/test_fuzzy.rb

# Run linter
lint:
	bundle exec rubocop

# Run CI (tests + linter)
ci:
	bundle exec rake ci

# Clean coverage reports
clean:
	rm -rf coverage/