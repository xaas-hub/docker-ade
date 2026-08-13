# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
|---------|--------------------|
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please DO NOT file a public issue for security vulnerabilities.**

Instead, please send an email to: **<dev@frugan.it>**

Include the following information:
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Any suggested fixes (if available)

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt within 48 hours
2. **Assessment**: We will assess the vulnerability within 5 business days
3. **Resolution**: We will work to resolve critical issues within 30 days
4. **Disclosure**: We will coordinate with you on responsible disclosure

### Responsible Disclosure

We believe in responsible disclosure. We ask that you:
- Give us reasonable time to investigate and fix the issue
- Do not publicly disclose the vulnerability until we've had a chance to fix it
- Do not exploit the vulnerability for malicious purposes

### Security Best Practices

When running docker-ade:

1. **X11 access**: `run.sh` uses `xhost +SI:localuser:$(id -un)`; never use
   `xhost +local:` or `xhost +`, which grant access to every local client
2. **Local use only**: no ports are published; the GUI travels over the X11
   unix socket
3. **Sensitive data**: `./data` holds tax credentials, workspaces and signed
   declarations — keep it out of version control and off shared storage
4. **Never expose over the network** without a TLS reverse proxy with
   authentication in front, preferably reachable only from a VPN
5. **Checksums**: Desktop Telematico is verified against `DT_SHA256` on every
   install path, including local copies from `vendor/`

## Security Contact

For security-related questions or concerns:
- Email: <dev@frugan.it>
- GitHub: [@frugan-dev](https://github.com/frugan-dev)

## Acknowledgments

We appreciate the security research community's efforts in responsibly disclosing vulnerabilities. Security researchers who help us improve this project will be acknowledged in our security advisories (with their permission).
