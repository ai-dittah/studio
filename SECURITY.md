# Security Policy

## Reporting a Vulnerability

We strongly encourage the responsible disclosure of security vulnerabilities. If you discover a security issue within **Dittah Studio**, please do not open a public issue. Instead, follow the process below:

1. **Email us:** Send a detailed report to **support@dittah.com**.
2. **Include Details:** Please provide a description of the vulnerability, steps to reproduce it, and the potential impact.
3. **Response Time:** We aim to acknowledge all security reports within 48 hours and provide a timeline for a fix.

## Our Security Philosophy

Dittah Studio is designed with a **privacy-first** and **on-premise** mindset.

- **Data Sovereignty:** Because Dittah is self-hosted, your documents and credentials never leave your infrastructure.
- **Deterministic Execution:** By freezing AI-generated code, we minimize "prompt injection" risks during runtime.
- **Role-Based Access:** We maintain strict authorization layers to ensure users only access the documents they are permitted to see.

## Supported Versions

Only the latest version of the Docker images provided on [Docker Hub](https://hub.docker.com/u/dittah) is supported for security updates. We recommend running `./update.sh` regularly to ensure you have the latest patches.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| < 1.0   | No        |

## Disclosure Policy

When a vulnerability is reported, we will:

1. Validate the report.
2. Work on a patch.
3. Notify the community to update their Docker images via our GitHub repository and website.
