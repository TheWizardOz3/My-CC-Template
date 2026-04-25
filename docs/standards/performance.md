# Performance Standards

> Detailed performance guidelines extracted from `AGENTS.md` §9. Load on demand.

---

## Frontend Performance

- Lazy load routes and heavy components
- Optimize images (WebP, proper sizing, lazy loading)
- Minimize bundle size (tree shaking, code splitting)
- Debounce/throttle expensive operations
- Memoize expensive calculations and components
- Avoid layout thrashing (batch DOM reads/writes)
- Use virtualization for long lists

---

## Backend Performance

- Use database indexes for frequently queried fields
- Paginate list endpoints (never return unbounded results)
- Implement caching where appropriate (with invalidation strategy)
- Use connection pooling for databases
- Batch database operations when possible
- Optimize N+1 queries (use joins or dataloaders)

---

## Performance Anti-Patterns

- Fetching data not needed for current view
- Synchronous operations that could be async
- Blocking the event loop with CPU-intensive tasks
- Unbounded queries or memory accumulation
- Missing database indexes on foreign keys
