#!/bin/bash
# safety-guard.sh — Unified security, privacy, and domain guard (PreToolUse hook)
#
# Sections (in execution order, by tool):
#   1. Domain blocking   — WebFetch to login-walled domains (x.com, twitter.com)
#   2. Sensitive paths   — Write/Edit/MultiEdit to ~/.ssh, ~/.aws, shell rc, LaunchAgents
#                          (NOT ~/.claude/* — that's handled via permission ask in settings.json)
#   3. Bash blocking     — dangerous shell patterns (rm, sudo, force-push, db drops, exfil, etc.)
#   4. Secret scanning   — credential literals in command strings
#   5. Financial guard   — outbound content with financial data after sensitive reads
#
# Exit 0 = allow, Exit 2 = block (stderr fed back to Claude as error)
#
# Two-tier philosophy:
#   - This hook = HARD BLOCK on truly catastrophic ops (no override possible)
#   - permissions.ask in settings.json = APPROVAL PROMPT on reversible-but-risky ops
#     (gh pr merge, vercel rm, git branch -D, ~/.claude edits, MCP updates/deletes)

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ══════════════════════════════════════════════════════════════════════
# Section 1: Domain Blocking (WebFetch)
# ══════════════════════════════════════════════════════════════════════
if [[ "$TOOL" == "WebFetch" ]]; then
  URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')
  [[ -z "$URL" ]] && exit 0

  # Anchored domain matching: catch x.com, twitter.com, and subdomains
  # Avoids false positives on flex.com, next.com, etc.
  if echo "$URL" | grep -qEi '(^https?://(www\.)?(x\.com|twitter\.com)|://(mobile|m)\.(x\.com|twitter\.com))'; then
    cat >&2 <<'EOF'
BLOCKED: WebFetch to x.com/twitter.com returns login walls. Use xurl instead:
- Post: xurl post "text"
- Reply: xurl reply TWEET_ID "text"
- Search: xurl search "query" -n 10
- Read a tweet: xurl read TWEET_ID
- Full workflow: invoke /replies skill
EOF
    exit 2
  fi
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════
# Section 2: Sensitive Path Guard (Write / Edit / MultiEdit)
# ══════════════════════════════════════════════════════════════════════
# Stops the model from writing to files holding credentials or macOS persistence.
# ~/.claude/* is NOT in this list — it's gated via permission "ask" so you can
# instruct Claude to edit its own hooks/settings with one approval click.
if [[ "$TOOL" == "Write" || "$TOOL" == "Edit" || "$TOOL" == "MultiEdit" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  [[ -z "$FILE_PATH" ]] && exit 0

  EXPANDED="${FILE_PATH/#\~/$HOME}"

  PATH_PATTERNS=(
    "^$HOME/\.ssh(/|$)"                                  # SSH keys, authorized_keys, config
    "^$HOME/\.aws(/|$)"                                  # AWS credentials, config
    "^$HOME/\.gnupg(/|$)"                                # GPG keys
    "^$HOME/\.kube(/|$)"                                 # Kubernetes config
    "^$HOME/\.config/(gcloud|gh)(/|$)"                   # gcloud / gh auth
    "^$HOME/\.netrc$"                                    # netrc credentials
    "^$HOME/\.gitconfig$"                                # global git config
    "^$HOME/\.(zshrc|bashrc|bash_profile|profile|zprofile|zshenv|zlogin)$"  # shell rc
    "^$HOME/Library/LaunchAgents(/|$)"                   # macOS user persistence
    "^$HOME/Library/LaunchDaemons(/|$)"                  # macOS user persistence
    "^/etc(/|$)"                                         # system config
    "^/usr(/|$)"                                         # system binaries
    "^/System(/|$)"                                      # macOS system
    "^/Library/LaunchDaemons(/|$)"                       # system-wide persistence
  )

  for pattern in "${PATH_PATTERNS[@]}"; do
    if echo "$EXPANDED" | grep -qE "$pattern"; then
      cat >&2 <<EOF
BLOCKED: Write/Edit to sensitive path: $FILE_PATH
This path is guarded against credential theft and macOS persistence.
If you really need to change it, ask the user to make the edit manually.
EOF
      exit 2
    fi
  done
  exit 0
fi

# Hook only inspects Bash beyond this point. MCP tools and other tools are
# gated via permission rules in settings.json (allow/ask/deny).
[[ "$TOOL" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

# Strip git commit message from pattern matching — keywords inside -m "..." are not executable
# e.g. "git commit -m 'fix: remove sudo calls'" should not trigger the sudo block
COMMAND_FOR_MATCHING=$(echo "$COMMAND" | sed "s/git commit.*-m ['\"][^'\"]*['\"]//g")

# ══════════════════════════════════════════════════════════════════════
# Section 3: Command Blocking (Bash) — HARD BLOCK, no override
# ══════════════════════════════════════════════════════════════════════

PATTERNS=(
  # ──── Filesystem destruction ────
  # 0: rm in command position (after ^, ;, &, |) — avoids false positives in strings
  '(^|[;&|])\s*rm\b'
  # 1: find -delete or find -exec rm
  '\bfind\b.*(-delete|-exec\s+rm)'
  # 2: file truncation via redirect to absolute path
  '^\s*>\s*/|;\s*>\s*/|\|\s*>\s*/'
  # 3: mkfs, dd of=, fdisk, parted, diskutil erase
  '\b(mkfs|dd\b.*of=|fdisk|parted|diskutil\s+erase)'
  # 4: file deletion via python/perl (bypasses rm block)
  '\bpython3?\b.*\bos\.(remove|unlink|rmdir)\b|\bshutil\.(rmtree|move)\b|\bperl\b.*\bunlink\b'

  # ──── Privilege & system mods ────
  # 5: sudo/doas
  '\bsudo\b|\bdoas\b'
  # 6: writes to system directories
  '(mv|cp|ln|chmod|chown)\s.*\s/(etc|usr|System|Library)/'
  # 7: kill PID 1, killall, shutdown, reboot, halt
  '\b(kill\s+-9\s+1\b|killall|shutdown|reboot|halt)\b'

  # ──── Network pipe-to-shell & exfil ────
  # 8: curl/wget piped to shell
  '(curl|wget|fetch)\s.*\|\s*(bash|sh|zsh|source)'
  # 9: curl/wget uploading local files
  '(curl|wget)\s.*(-d\s*@|-F\s.*=@|--data-binary\s*@|--upload-file)'
  # 10: scp/rsync sending local data to a remote host (user@host: form)
  '\b(scp|rsync)\b\s+[^@]*\s+\S+@\S+:'
  # 11: netcat / ncat with file input (exfil)
  '\b(nc|ncat)\b\s+\S+\s+[0-9]+\s*<'
  # 12: pbcopy of credentials (clipboard → human paste anywhere)
  '\bpbcopy\b\s*<\s*\S*(\.env|\.pem|\.key|credentials|secret)|cat\s+\S*(\.env|\.pem|\.key|credentials|secret)\b.*\|\s*pbcopy'

  # ──── Secrets-file & credential-file writes ────
  # 13: redirect overwriting .env files
  '[12]?>>?\s*\S*\.env\b'
  # 14: tee writing to sensitive paths (bypasses redirect block)
  '\btee\b\s+.*(/etc/|/usr/|/System/|\.ssh/|\.aws/|\.zshrc|\.bashrc|\.bash_profile|\.gitconfig|\.netrc)'
  # 15: redirect overwriting user credential files (~/.ssh, ~/.aws, etc.)
  '>\s*\S*(\.ssh/|\.aws/|\.gnupg/|\.netrc)'

  # ──── Git destructive ────
  # 16: force push (covers -f, --force, --force-with-lease)
  '\bgit\b.*\bpush\b.*(-f\b|--force\b|--force-with-lease)'
  # 17: git checkout ., restore ., clean -f
  '\bgit\b.*(checkout\s+\.\s*$|restore\s+\.\s*$|clean\s+-[a-zA-Z]*f)'
  # 18: broad git staging (git add . or git add -A)
  '\bgit\b\s+add\s+(-A\b|\.(\s|$))'
  # 19: reflog expiry (silently destroys recovery history)
  '\bgit\b\s+reflog\s+expire.*--expire=now.*--all'

  # ──── GitHub CLI destructive (truly catastrophic only) ────
  # 20: gh repo delete / secret set/delete / variable set/delete / api -X DELETE|PUT|PATCH
  # NOTE: pr merge, pr close, release delete moved to permission "ask"
  '\bgh\b\s+(repo\s+delete|secret\s+(set|delete)|variable\s+(set|delete)|api\s+.*-X\s+(DELETE|PUT|PATCH))'

  # ──── Database destruction ────
  # 21: prisma migrate reset / db push --force-reset / migrate resolve --rolled-back
  '\bprisma\b.*(migrate\s+reset|db\s+push.*--force-reset|migrate\s+resolve.*--rolled-back)'
  # 22: destructive SQL via psql -c (DROP DATABASE|TABLE|SCHEMA / TRUNCATE / DELETE FROM)
  '\bpsql\b.*(-c|--command)\s+.*\b(DROP\s+(DATABASE|TABLE|SCHEMA)|TRUNCATE|DELETE\s+FROM)\b'

  # ──── Package publishing ────
  # 23: npm/pnpm/yarn/bun publish — public + irreversible
  '\b(npm|pnpm|yarn|bun)\b\s+publish\b'

  # ──── SSH (existing siteground rule) ────
  # 24: destructive SSH commands on siteground (cp allowed — not destructive)
  '\bssh\b.*\bsiteground\b.*\b(rm|mv)\b'
)

MESSAGES=(
  "BLOCKED: rm is not permitted. Use mv <target> ~/.Trash/ instead."
  "BLOCKED: find with -delete or -exec rm is destructive. List files first with find alone."
  "BLOCKED: file truncation via redirect to absolute path."
  "BLOCKED: disk/filesystem modification not permitted."
  "BLOCKED: file deletion via python/perl. Use mv <target> ~/.Trash/ instead."
  "BLOCKED: privilege escalation (sudo/doas) not permitted."
  "BLOCKED: modification of system directories not permitted."
  "BLOCKED: system process/power management not permitted."
  "BLOCKED: piping remote content to shell is not permitted."
  "BLOCKED: uploading local files via curl/wget. Ask user first."
  "BLOCKED: scp/rsync to remote host with local source. Could exfiltrate data."
  "BLOCKED: netcat with file input. Could exfiltrate file contents."
  "BLOCKED: copying credentials to clipboard. Don't move secrets through pbcopy."
  "BLOCKED: overwriting .env files via redirect. Use Edit tool instead."
  "BLOCKED: tee to sensitive path. Use Edit tool for legit edits."
  "BLOCKED: redirect overwriting credential/key file."
  "BLOCKED: force push detected. Only regular push is permitted."
  "BLOCKED: destructive git operation (checkout ., restore ., clean -f). Too broad — specify files."
  "BLOCKED: broad git staging (git add . / git add -A). Stage specific files instead."
  "BLOCKED: git reflog expiry destroys recovery history. Don't run this."
  "BLOCKED: catastrophic gh CLI op (repo delete / secret set / non-GET api). Ask the user to run it."
  "BLOCKED: destructive Prisma op (migrate reset / db push --force-reset). Wipes local data."
  "BLOCKED: destructive SQL via psql (DROP / TRUNCATE / DELETE FROM). Ask the user to run it."
  "BLOCKED: package publish detected. Ask the user to publish manually."
  "BLOCKED: destructive SSH command on siteground. Give the user the exact command to run in their terminal."
)

# Short-circuit loop: exit on first match
for i in "${!PATTERNS[@]}"; do
  if echo "$COMMAND_FOR_MATCHING" | grep -qE "${PATTERNS[$i]}"; then
    echo "${MESSAGES[$i]}" >&2
    exit 2
  fi
done

# ══════════════════════════════════════════════════════════════════════
# Section 4: Secret Scanning
# ══════════════════════════════════════════════════════════════════════
# Catches hardcoded credentials appearing literally in command strings.
# Note: `cat ~/.aws/credentials` contains no key literal — it passes.

SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}'
  'ghp_[0-9a-zA-Z]{36}'
  'github_pat_[a-zA-Z0-9_]{82}'
  'sk-ant-api03-[a-zA-Z0-9_\-]{93}AA'
  'sk-[a-zA-Z0-9]{20}T3BlbkFJ[a-zA-Z0-9]{20}'
  '-----BEGIN[ A-Z0-9_\-]{0,100}PRIVATE KEY'
  're_[a-zA-Z0-9]{20,}'
  'pplx-[a-zA-Z0-9]{20,}'
)

SECRET_MESSAGES=(
  "BLOCKED: AWS access key literal in command. Use env vars or ~/.aws/credentials."
  "BLOCKED: GitHub PAT literal in command. Use gh auth login or GITHUB_TOKEN env var."
  "BLOCKED: GitHub fine-grained PAT literal in command. Use GITHUB_TOKEN env var."
  "BLOCKED: Anthropic API key literal in command. Use ANTHROPIC_API_KEY env var."
  "BLOCKED: OpenAI API key literal in command. Use OPENAI_API_KEY env var."
  "BLOCKED: Private key material in command. Do not embed key content in shell commands."
  "BLOCKED: Resend API key literal in command. Use RESEND_API_KEY env var."
  "BLOCKED: Perplexity API key literal in command. Use PERPLEXITY_API_KEY env var."
)

for i in "${!SECRET_PATTERNS[@]}"; do
  if echo "$COMMAND_FOR_MATCHING" | grep -qE -- "${SECRET_PATTERNS[$i]}"; then
    echo "${SECRET_MESSAGES[$i]}" >&2
    exit 2
  fi
done

# ══════════════════════════════════════════════════════════════════════
# Section 5: Financial Guard
# ══════════════════════════════════════════════════════════════════════
# Two-gate logic: only blocks when BOTH gates fire.
#   Gate 1: Was sensitive financial data read this session? (flag file)
#   Gate 2: Does the outbound content contain financial patterns?

FLAG_FILE="${CLAUDE_SENSITIVE_SESSION_FILE:-/tmp/claude-sensitive-session-$$}"
if [[ -f "$FLAG_FILE" ]]; then
  # Override: user explicitly confirmed the content is safe
  echo "$COMMAND" | grep -q '^# SAFE-OVERRIDE:' && exit 0

  # Only gate outbound Bash: clipboard writes, HTTP POSTs, X posting scripts
  if echo "$COMMAND" | grep -qE '(pbcopy|curl.*(--data|-d|-F|--upload-file)|wget.*--post|x-post\.sh|post-to-x\.py|xurl\s+(post|reply|quote|dm))'; then
    MATCH=""

    # Dollar amounts
    echo "$COMMAND" | grep -qE '\$[0-9,]+' && MATCH=1

    # Percentage in financial context
    if [[ -z "$MATCH" ]]; then
      echo "$COMMAND" | grep -qiE '[0-9]+%[^a-z]*\b(return|yield|rate|allocation|burn|interest|growth)\b' && MATCH=1
      echo "$COMMAND" | grep -qiE '\b(return|yield|rate|allocation|burn|interest|growth)\b[^a-z]*[0-9]+%' && MATCH=1
    fi

    # Account-related terms
    if [[ -z "$MATCH" ]]; then
      echo "$COMMAND" | grep -qiE '\b(account\s+number|routing\s+number|balance|portfolio|brokerage|checking|savings)\b' && MATCH=1
    fi

    # Specific financial terms
    if [[ -z "$MATCH" ]]; then
      echo "$COMMAND" | grep -qiE '\b(runway|burn\s+rate|net\s+worth|retirement|401k|roth|ira|dividend|drawdown|withdrawal|contribution|rebalance)\b' && MATCH=1
    fi

    # 8+ digit sequences that look like account numbers
    if [[ -z "$MATCH" ]]; then
      echo "$COMMAND" | grep -qE '\b[0-9]{8,}\b' && MATCH=1
    fi

    if [[ -n "$MATCH" ]]; then
      cat >&2 <<'EOF'
BLOCKED: Sensitive financial data was read this session.
This outbound action contains financial patterns.
Sanitize the content or confirm with: # SAFE-OVERRIDE: <command>
EOF
      exit 2
    fi
  fi
fi

# ── Passed all checks ────────────────────────────────────────────
exit 0
