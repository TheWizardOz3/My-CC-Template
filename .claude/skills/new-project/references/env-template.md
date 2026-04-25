# Environment Template (used by /new-project Phase 3)

Generates `.env.example` and documents setup. Source of truth for env-var requirements is the architecture answers — don't ask twice.

---

## Step 1: Derive required env vars from architecture

Walk the architecture answers and produce a list:

| Architecture choice | Env vars to add |
|---|---|
| Postgres | `DATABASE_URL` |
| MongoDB | `MONGODB_URI` |
| Redis | `REDIS_URL` |
| Clerk | `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY` |
| Auth0 | `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET` |
| Supabase | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` |
| Stripe | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PUBLISHABLE_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| Sentry | `SENTRY_DSN` |
| Resend / SendGrid / Postmark | `<provider>_API_KEY` |
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET` (if used) |

For anything in the integrations list that isn't here, add it explicitly with a one-line comment.

---

## Step 2: Ask the user

1. **Which services do you already have accounts for?** (free-form, list)
   → For those, the user has live credentials. For others, note "needs signup" in the env doc.
2. **Local dev port preferences?** (free-form, defaults: 3000 frontend, 8000 backend)
3. **Environment tiers?** (multiple-choice: dev-only · dev+prod · dev+staging+prod)

---

## Step 3: Write `.env.example`

Format:
```
# === <category> ===
VARIABLE_NAME=<placeholder>     # <one-line description>
```

Rules:
- **Never write real secrets** to `.env.example` (the safety-guard hook will block this anyway).
- Use placeholder values: `your_postgres_url_here`, `sk_test_replace_me`, etc.
- Group related vars (database, auth, third-party APIs).
- One-line comment per var explaining what it's for and where to get it.

---

## Step 4: User-supplied tasks (confirm don't auto-do)

Tell the user exactly what they need to do themselves:

> To finish env setup:
> 1. Copy `.env.example` → `.env.local`
> 2. Fill in values for: `<list of services they said they have accounts for>`
> 3. Sign up + add values for: `<list of services they need to create accounts for>`
> 4. (Optional) `.env.staging`, `.env.production` for additional tiers

**Do NOT** run any signup flows or create real credentials on the user's behalf.

---

## Step 5: Update README setup section (if README exists)

Append a "Quick Start" section:
```markdown
## Quick Start
1. `pnpm install` (or equivalent for your package manager)
2. Copy `.env.example` to `.env.local` and fill in values
3. `<dev command>` to start the local server
4. Visit `http://localhost:<port>`
```

If no README exists yet, note "README pending — populate during Phase 9 of restructure or in a separate `/ship` pass."
