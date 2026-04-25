# Coding Standards

> Detailed coding standards extracted from `AGENTS.md` §5. Load on demand when writing or reviewing code. The general principles (§5.1) remain in `AGENTS.md`.

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Variables | camelCase, descriptive | `userEmail`, `isLoading` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| Functions | camelCase, verb prefix | `getUserById()`, `validateInput()` |
| Classes | PascalCase, noun | `UserService`, `PaymentProcessor` |
| Interfaces/Types | PascalCase, descriptive | `UserProfile`, `ApiResponse` |
| Files (components) | PascalCase | `UserProfile.tsx` |
| Files (utilities) | camelCase or kebab-case | `formatDate.ts`, `api-client.ts` |
| CSS classes | kebab-case or BEM | `user-profile`, `btn--primary` |
| Database tables | snake_case, plural | `user_accounts`, `order_items` |
| Environment variables | SCREAMING_SNAKE_CASE | `DATABASE_URL`, `API_KEY` |

**Naming Guidelines:**
- Boolean variables: prefix with `is`, `has`, `should`, `can` (`isActive`, `hasPermission`)
- Arrays: use plural nouns (`users`, `orderItems`)
- Functions returning boolean: prefix with `is`, `has`, `can`, `should`
- Async functions: suffix with `Async` only if sync version exists
- Event handlers: prefix with `handle` or `on` (`handleSubmit`, `onClick`)

---

## Code Organization

**File Structure:**
```
1. Imports (external → internal → relative)
2. Type definitions/interfaces
3. Constants
4. Helper functions (if file-scoped)
5. Main export (component/class/function)
6. Sub-components (if applicable)
```

**Import Order:**
1. External packages (node_modules)
2. Internal packages (monorepo packages)
3. Absolute imports (path aliases)
4. Relative imports (parent → sibling → child)
5. Style imports
6. Type-only imports (if separate)

---

## Functions & Methods

- Aim for small functions (<50 lines), but prioritize cohesion (max ~100 lines)
- Max parameters: 3-4 (use options object for more)
- Max nesting depth: 3 levels
- Always provide return types for public functions
- Use early returns to reduce nesting
- Avoid side effects in pure functions

```typescript
// ❌ Avoid
function processUser(user, shouldSendEmail, shouldUpdateDb, shouldLog, options) {
  if (user) {
    if (user.isActive) {
      if (shouldUpdateDb) {
        // deeply nested logic
      }
    }
  }
}

// ✅ Prefer
function processUser(user: User, options: ProcessUserOptions): ProcessResult {
  if (!user) return { success: false, error: 'No user provided' };
  if (!user.isActive) return { success: false, error: 'User inactive' };

  return executeProcessing(user, options);
}
```

---

## Comments & Documentation

**When to Comment:**
- Complex algorithms or business logic
- Non-obvious "why" (not "what")
- Workarounds with links to issues/tickets
- Public API documentation (JSDoc/TSDoc)
- TODO/FIXME with ticket reference

**When NOT to Comment:**
- Obvious code behavior
- Restating what code does
- Commented-out code (delete it)
- Outdated information

```typescript
// ❌ Bad: restates the obvious
// Increment counter by 1
counter++;

// ✅ Good: explains the why
// Offset by 1 because API returns 0-indexed pages but UI displays 1-indexed
const displayPage = apiPage + 1;

// ✅ Good: documents workaround
// HACK: Safari doesn't support this API, remove when dropping Safari 14 support
// See: https://github.com/org/repo/issues/123
```

---

## TypeScript Specifics

- Enable strict mode
- Avoid `any` — use `unknown` and narrow, or define proper types
- Prefer interfaces for object shapes, types for unions/intersections
- Use `as const` for literal types
- Leverage discriminated unions for state
- Export types alongside their implementations

```typescript
// ❌ Avoid
const config: any = getConfig();
function process(data: any): any { }

// ✅ Prefer
const config: AppConfig = getConfig();
function process(data: InputData): ProcessedResult { }

// ✅ Use discriminated unions
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```
