#!/usr/bin/env bash
# PostToolUse hook: Detect plaintext secrets in appsettings*.json.
# Allow placeholder values like ${...}, SecretRef:, or explicit User Secrets references.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0
[[ -f "$FILE_PATH" ]] || exit 0

# Only scan appsettings*.json
BASENAME=$(basename "$FILE_PATH")
[[ "$BASENAME" == appsettings*.json ]] || exit 0

VIOLATIONS=""

# Extract lines with suspicious-looking values
# Password/Secret/ApiKey/ConnectionString with non-placeholder value
SUSPICIOUS=$(grep -nEi '"(Password|PasswordHash|Secret|ClientSecret|ApiKey|Api[_ ]?Token|AccessKey|SecretKey|PrivateKey)"[[:space:]]*:[[:space:]]*"[^$"{]' "$FILE_PATH" 2>/dev/null | head -5)
if [[ -n "$SUSPICIOUS" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  Plaintext credential fields:\n${SUSPICIOUS}"
fi

# ConnectionString with Password= or Pwd=
CONN=$(grep -nEi '"ConnectionString"[[:space:]]*:[[:space:]]*"[^"]*((Password|Pwd)=)[^$"{;]' "$FILE_PATH" 2>/dev/null | head -3)
if [[ -n "$CONN" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  ConnectionString with inline password:\n${CONN}"
fi

# Raw-looking JWT or Bearer token value (40+ alphanum + dots/dashes)
TOKEN=$(grep -nE '"[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]+"' "$FILE_PATH" 2>/dev/null | head -2)
if [[ -n "$TOKEN" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  Possible JWT/bearer token literal:\n${TOKEN}"
fi

if [[ -n "$VIOLATIONS" ]]; then
  cat >&2 <<MSG
SECRET IN CONFIG: $BASENAME
$(echo -e "$VIOLATIONS")

Iron Law #28: Secrets MUST NOT be committed in appsettings.json.
Use User Secrets (dotnet user-secrets set), environment variables,
Azure Key Vault, or AWS Secrets Manager. In config files, prefer
placeholders like "\${SECRET_NAME}" resolved at runtime.
MSG
  exit 2
fi
