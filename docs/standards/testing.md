# Testing Standards

> Detailed testing quality standards extracted from `AGENTS.md` §8. Load on demand. Coverage (§8.1) and what-to-test guidance (§8.2) remain in `AGENTS.md`.

---

## Test Quality Standards

- Tests are independent (no shared state)
- Tests are deterministic (no flaky tests)
- Tests are fast (mock external services)
- Descriptive test names: `should [expected behavior] when [condition]`
- Arrange-Act-Assert structure
- One logical assertion per test

```typescript
// ❌ Vague test name
test('user validation', () => { });

// ✅ Descriptive test name
test('should return validation error when email format is invalid', () => {
  // Arrange
  const invalidEmail = 'not-an-email';

  // Act
  const result = validateUserEmail(invalidEmail);

  // Assert
  expect(result.isValid).toBe(false);
  expect(result.error).toBe('Invalid email format');
});
```
