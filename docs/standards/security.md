# Security Standards

> Detailed security checklist extracted from `AGENTS.md` §7. Load on demand. Data handling (§7.1) and auth/authz (§7.2) remain in `AGENTS.md`.

---

## Security Checklist

- [ ] Input validation on all user inputs
- [ ] Output encoding/escaping for XSS prevention
- [ ] Parameterized queries for SQL injection prevention
- [ ] CSRF tokens on state-changing requests
- [ ] Rate limiting on sensitive endpoints
- [ ] Proper CORS configuration
- [ ] Security headers (CSP, X-Frame-Options, etc.)
- [ ] Sensitive data encrypted at rest and in transit
- [ ] Audit logging for sensitive operations
