# dilisense_PEP_client

A Ruby gem providing a client for [Dilisense's](https://dilisense.com) PEP (Politically Exposed Persons) and sanctions screening API. This gem is designed for Estonian financial institutions and FinTech companies requiring AML/KYC compliance through automated screening of individuals and entities against global PEP databases and sanctions lists.

[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%202.7-red)](https://www.ruby-lang.org/en/)
[![Gem Version](https://img.shields.io/gem/v/dilisense_pep_client)](https://rubygems.org/gems/dilisense_pep_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

The Dilisense PEP Client provides a simple, industrial-grade Ruby interface for:

- **Individual Screening**: Screen persons against PEP and sanctions databases
- **Entity Screening**: Screen companies and organizations against sanctions lists
- **Fuzzy Matching**: Find potential matches even with name variations or typos
- **Compliance Logging**: Enterprise-grade audit trails for regulatory compliance
- **Error Handling**: Comprehensive error management with detailed context
- **Security**: Built-in data sanitization and PII protection

## Features

### Core Functionality
- Screen individuals with name, date of birth, and gender parameters
- Screen entities (companies/organizations) with flexible search options
- Support for fuzzy search to catch name variations and typos
- Real-time screening against Dilisense's comprehensive databases

### Enterprise Features
- **Industrial-grade error handling** with detailed error contexts
- **Comprehensive logging** with PII anonymization for compliance
- **Circuit breaker pattern** for API resilience and fault tolerance
- **Input validation and sanitization** to prevent injection attacks
- **Metrics collection** for monitoring and performance analysis
- **Audit logging** for AML/KYC/GDPR compliance requirements

### Security & Compliance
- Automatic PII anonymization in logs and error messages
- Security event logging and monitoring
- Built-in data sanitization and validation
- Support for multiple compliance frameworks (AML, KYC, GDPR, MiFID)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dilisense_pep_client'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install dilisense_pep_client
```

## Configuration

### Basic Setup

The gem requires a Dilisense API key to function. You can configure it in several ways:

#### Option 1: Environment Variable (Recommended)

Set your API key as an environment variable:

```bash
export DILISENSE_API_KEY="your_api_key_here"
```

Or add it to your `.env` file:

```env
DILISENSE_API_KEY=your_api_key_here
```

#### Option 2: Configuration Block

```ruby
require 'dilisense_pep_client'

DilisensePepClient.configure do |config|
  config.api_key = "your_api_key_here"
  config.timeout = 30  # Request timeout in seconds (default: 30)
  config.base_url = "https://api.dilisense.com"  # API base URL (default)
end
```

### Advanced Configuration

For production environments, you may want to customize additional settings:

```ruby
DilisensePepClient.configure do |config|
  config.api_key = ENV['DILISENSE_API_KEY']
  config.timeout = 45  # Increase timeout for slower networks
end
```

## Quick Start

### Individual Screening

Screen a person against PEP and sanctions databases:

```ruby
require 'dilisense_pep_client'

# Basic individual screening
results = DilisensePepClient.check_individual(
  names: "Vladimir Putin"
)

# Enhanced screening with additional parameters
results = DilisensePepClient.check_individual(
  names: "Vladimir Putin",
  dob: "07/10/1952",
  gender: "male",
  fuzzy_search: 1  # Enable fuzzy matching
)

# Process results
results.each do |person|
  puts "Name: #{person[:name]}"
  puts "Source Type: #{person[:source_type]}"
  puts "PEP Type: #{person[:pep_type]}" if person[:pep_type]
  puts "Total Records: #{person[:total_records]}"
  puts "---"
end
```

### Entity Screening

Screen companies and organizations:

```ruby
# Screen a company
results = DilisensePepClient.check_entity(
  names: "Bank Rossiya"
)

# Enhanced entity screening
results = DilisensePepClient.check_entity(
  names: "Gazprom",
  fuzzy_search: 2  # More aggressive fuzzy matching
)

# Process entity results
results.each do |entity|
  puts "Entity: #{entity[:name]}"
  puts "Source Type: #{entity[:source_type]}"
  puts "Sanctions: #{entity[:sanction_details]}" if entity[:sanction_details]
  puts "Sources: #{entity[:sources].join(', ')}"
  puts "---"
end
```

### Using the Client Directly

For more control, you can instantiate the client directly:

```ruby
client = DilisensePepClient::Client.new

# Individual screening
individual_results = client.check_individual(
  names: "Xi Jinping",
  dob: "15/06/1953",
  gender: "male"
)

# Entity screening
entity_results = client.check_entity(
  names: "Huawei Technologies"
)
```

## Usage Examples

### Estonian eID Integration

For Estonian financial institutions integrating with eID systems:

```ruby
# Screen Estonian resident
results = DilisensePepClient.check_individual(
  names: "#{first_name} #{last_name}",
  dob: estonian_personal_code_to_dob(personal_code),
  gender: extract_gender_from_personal_code(personal_code)
)

# Check if person is a PEP or sanctioned
is_pep = results.any? { |person| person[:source_type] == 'PEP' }
is_sanctioned = results.any? { |person| person[:source_type] == 'SANCTION' }

if is_pep || is_sanctioned
  # Handle enhanced due diligence requirements
  trigger_enhanced_due_diligence(results)
end
```

### Batch Processing

```ruby
# Screen multiple individuals
people_to_screen = [
  { names: "Person One", dob: "01/01/1980" },
  { names: "Person Two", dob: "02/02/1975" }
]

people_to_screen.each do |person|
  begin
    results = DilisensePepClient.check_individual(**person)
    
    # Process results
    if results.any?
      puts "Potential matches found for #{person[:names]}"
      # Handle matches according to your compliance procedures
    end
    
    # Rate limiting - wait between requests
    sleep(2)
    
  rescue DilisensePepClient::Error => e
    puts "Error screening #{person[:names]}: #{e.message}"
    # Log error for audit trail
  end
end
```

### Error Handling

The gem provides comprehensive error handling:

```ruby
begin
  results = DilisensePepClient.check_individual(
    names: "Test Person",
    dob: "invalid-date"  # This will cause a validation error
  )
rescue DilisensePepClient::ValidationError => e
  puts "Validation error: #{e.message}"
  puts "Validation errors: #{e.validation_errors}"
rescue DilisensePepClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
  # Check your API key configuration
rescue DilisensePepClient::APIError => e
  puts "API error: #{e.message}"
  puts "Status code: #{e.status}"
  puts "Retryable? #{e.retryable?}"
rescue DilisensePepClient::NetworkError => e
  puts "Network error: #{e.message}"
  # Implement retry logic for network issues
rescue DilisensePepClient::Error => e
  puts "General error: #{e.message}"
  puts "Error context: #{e.context}"
end
```

### Fuzzy Search Examples

```ruby
# Search with typos and variations
results = DilisensePepClient.check_individual(
  names: "Vladmir Putin",  # Typo in "Vladimir"
  fuzzy_search: 1
)

# More aggressive fuzzy matching
results = DilisensePepClient.check_individual(
  names: "V Putin",  # Abbreviated first name
  fuzzy_search: 2
)

# Entity fuzzy search
results = DilisensePepClient.check_entity(
  names: "Bank Russia",  # Variation of "Bank Rossiya"
  fuzzy_search: 1
)
```

## Development and Testing

### Setting Up Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/dilisense_pep_client.git
   cd dilisense_pep_client
   ```

2. Install dependencies:
   ```bash
   make install
   # or
   bundle install
   ```

3. Set up your API key for testing:
   ```bash
   cp .env.example .env
   # Edit .env and add your DILISENSE_API_KEY
   ```

### Running Tests

The gem includes comprehensive test suites:

```bash
# Show all available commands
make help

# Run all tests (unit + integration)
make test

# Run only unit tests (no API calls)
make unit_test

# Run integration tests with real API calls
make individual_test

# Run fuzzy search tests
make test_fuzzy

# Run entity screening tests
make entity_test

# Run linter
make lint

# Run CI suite (tests + linting)
make ci
```

### Test Categories

- **Unit Tests**: Test internal logic without external API calls
- **Integration Tests**: Test against live Dilisense API (requires API key)
- **Fuzzy Search Tests**: Test fuzzy matching capabilities
- **Entity Tests**: Test company/organization screening

**Note**: Integration tests include automatic 2-second delays between requests to respect API rate limits.

## Architecture

The gem is designed with enterprise-grade architecture:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │    │  Configuration   │    │   Validation    │
│     Client      │───▶│    Manager       │───▶│   & Sanitization│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│  Circuit Breaker │───▶│   API Gateway   │
│   (Faraday)     │    │   & Resilience   │    │   (Dilisense)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Response      │    │     Logging      │───▶│   Monitoring    │
│   Processing    │    │   & Auditing     │    │   & Metrics     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Core Components

- **Client**: Main interface for API communication
- **Configuration**: Simple, flexible configuration management  
- **Validator**: Input validation and sanitization with security focus
- **Logger**: Structured logging with PII anonymization
- **Metrics**: Performance and business metrics collection
- **AuditLogger**: Compliance-focused audit trail generation
- **CircuitBreaker**: API resilience and fault tolerance
- **Errors**: Comprehensive error hierarchy with context

## API Reference

For detailed API documentation, see the inline documentation in the source code. Key classes:

- `DilisensePepClient::Client` - Main API client
- `DilisensePepClient::Configuration` - Configuration management
- `DilisensePepClient::Validator` - Input validation
- `DilisensePepClient::Logger` - Structured logging
- `DilisensePepClient::Error` - Error handling

## Performance Considerations

### Rate Limiting

The Dilisense API has rate limits. For production use:

1. Implement request queuing for batch operations
2. Add delays between requests (2+ seconds recommended)
3. Use the circuit breaker for resilience
4. Monitor API usage through the metrics system

### Caching

For high-volume applications, consider implementing caching:

```ruby
# Example with Redis caching (not included in gem)
class CachedScreeningService
  def self.screen_individual(params)
    cache_key = "screening:individual:#{Digest::SHA256.hexdigest(params.to_s)}"
    
    cached_result = Redis.current.get(cache_key)
    return JSON.parse(cached_result) if cached_result
    
    result = DilisensePepClient.check_individual(**params)
    Redis.current.setex(cache_key, 3600, result.to_json)  # 1 hour cache
    
    result
  end
end
```

## Compliance and Security

### Data Protection

- All PII is automatically anonymized in logs
- API keys are redacted from error messages and logs
- Response data is sanitized to prevent credential exposure
- Input validation prevents injection attacks

### Audit Trail

The gem provides comprehensive audit logging for compliance:

- All screening requests are logged with anonymized search terms
- API errors and security events are tracked
- User actions and system events are recorded
- Configurable retention periods for different compliance frameworks

### Regulatory Compliance

Supports multiple compliance frameworks:

- **AML (Anti-Money Laundering)**: Customer due diligence logging
- **KYC (Know Your Customer)**: Identity verification audit trails
- **GDPR**: Privacy-compliant logging with data subject rights
- **MiFID**: Financial services compliance requirements

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`make ci`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Guidelines

- Follow Ruby style guidelines (enforced by RuboCop)
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure security best practices
- Maintain backward compatibility when possible

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## Support

### Documentation

- [Dilisense API Documentation](https://dilisense.com/api)
- [Gem Documentation](https://rubydoc.info/gems/dilisense_pep_client)

### Contact

- **Email**: angelos@sorbet.ee
- **Company**: Sorbeet Payments OU
- **Issues**: [GitHub Issues](https://github.com/your-org/dilisense_pep_client/issues)

### Professional Services

For enterprise support, custom integrations, or compliance consulting, please contact us directly.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

---

**Note**: This gem is designed specifically for Estonian financial institutions and FinTech companies. It provides enterprise-grade features for PEP and sanctions screening as required by Estonian financial regulations and AML/KYC compliance standards.