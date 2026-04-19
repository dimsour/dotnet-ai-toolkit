#!/usr/bin/env bash
# PostToolUse hook: Output security Iron Laws when auth-related files are edited
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
if echo "$FILE_PATH" | grep -qiE '(auth|session|password|token|permission|admin|payment|login|credential|secret|jwt|identity|oauth)'; then
  cat >&2 <<MSG
SECURITY FILE DETECTED: $BASENAME
Iron Laws — verify these apply:
  - [Authorize] on ALL non-public endpoints (default to secure; opt out with [AllowAnonymous])
  - DTOs at API boundary — never expose EF entities
  - Hash passwords via PasswordHasher<T> or Rfc2898DeriveBytes — NEVER MD5/SHA1
  - JWT validation: issuer + audience + lifetime + signing key ALL required
  - Rate limit auth endpoints (AddRateLimiter)
  - Secrets via User Secrets / Key Vault / env vars — never appsettings.json
  - Anti-forgery tokens on state-changing forms
Consider: /dotnet:review security for full security audit
MSG
  exit 2
fi
