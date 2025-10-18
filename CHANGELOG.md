# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation in `docs/` directory
- GitHub issue templates and PR template
- CI/CD workflows for testing and linting
- Security policy and changelog
- Advanced README with badges and detailed setup

### Changed
- Updated `.gitignore` to include more file types
- Fixed malformed `SSL_ENABLED` line in `master/.env.example`
- Enhanced SSL certificate management

### Fixed
- Corrected environment variable formatting
- Improved error handling in management scripts

## [1.0.0] - 2025-10-19

### Added
- Initial release of MySQL Docker Replication setup
- Master/replica topology with MySQL 8.0
- SSL certificate generation and management
- Automated replication configuration
- Management script (`mange.sh`) for operations
- Docker Compose setup for both master and replica
- Environment-driven configuration
- Health checks and monitoring
- Documentation and troubleshooting guides

### Security
- SSL/TLS encryption support for replication
- Secure certificate generation
- Read-only replica configuration
- Password-protected MySQL instances
