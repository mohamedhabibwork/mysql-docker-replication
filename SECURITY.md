---
name: Security Policy
about: Report security vulnerabilities
---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow these steps:

1. **Do NOT** create a public GitHub issue
2. Email the maintainer directly at: [security contact needed]
3. Include a detailed description of the vulnerability
4. Provide steps to reproduce the issue
5. Include any relevant logs or screenshots

We will acknowledge receipt of your report within 48 hours and provide a detailed response within 7 days.

## Security Considerations

This project is designed for development and testing environments. For production use:

- Change all default passwords in `.env` files
- Use proper SSL certificates from a trusted CA
- Implement network security controls
- Regularly update Docker images
- Monitor logs for unusual activity
- Backup data regularly

## Common Security Practices

- Keep Docker and MySQL images updated
- Use strong, unique passwords
- Enable SSL/TLS encryption
- Limit network access to MySQL ports
- Regularly rotate certificates and credentials
