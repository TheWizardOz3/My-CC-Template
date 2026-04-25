# Error Handling Standards

> Detailed error handling patterns extracted from `AGENTS.md` §6. Load on demand. The principles (§6.1) remain in `AGENTS.md`.

---

## Error Handling Patterns

**API/Service Layer:**
```typescript
// Create typed error classes
class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public isOperational: boolean = true
  ) {
    super(message);
  }
}

class ValidationError extends AppError {
  constructor(message: string, public fields: Record<string, string>) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

// Centralized error handling
function handleError(error: unknown): ApiErrorResponse {
  if (error instanceof AppError && error.isOperational) {
    return { code: error.code, message: error.message, statusCode: error.statusCode };
  }

  // Log unexpected errors, return generic message
  logger.error('Unexpected error', { error });
  return { code: 'INTERNAL_ERROR', message: 'Something went wrong', statusCode: 500 };
}
```

**Frontend Components:**
- Use Error Boundaries for component trees
- Handle async errors in try/catch or .catch()
- Display appropriate error states to users
- Provide retry mechanisms where applicable

---

## Logging Standards

| Level | When to Use |
|-------|-------------|
| `error` | Unexpected failures, exceptions, operational issues |
| `warn` | Recoverable issues, deprecation notices, fallback triggered |
| `info` | Significant events (startup, shutdown, auth, transactions) |
| `debug` | Development diagnostics, request/response details |

**Log Context Requirements:**
- Operation being performed
- Relevant identifiers (userId, orderId, etc.)
- Duration for async operations
- Error stack traces (errors only)
