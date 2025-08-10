# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-08-10

### Fixed
- Fixed test suite configuration issues that were causing test failures
- Corrected configuration accessor methods in tests (removed incorrect `.config` method calls)
- Resolved API key loading issues in test environment
- All test suites now pass correctly (18 runs, 37 assertions, 0 failures, 0 errors, 0 skips)
- Improved test reliability and stability

### Changed
- Enhanced test helper setup to properly handle environment variable loading
- Streamlined test execution by removing unnecessary API availability checks

## [0.1.0] - 2025-08-10

### Added
- Initial release of DilisensePepClient Ruby gem
- Support for PEP (Politically Exposed Persons) screening via Dilisense API
- Support for entity/company sanctions screening
- Individual person screening with multiple parameters:
  - Name-based searches
  - Date of birth filtering
  - Gender filtering
  - Fuzzy search capabilities (distance 1 and 2)
  - Search all functionality
- Entity screening with fuzzy search support
- Comprehensive response formatting with grouped results
- Full test coverage with integration, unit, and fuzzy search tests
- MIT license
- Detailed documentation and usage examples