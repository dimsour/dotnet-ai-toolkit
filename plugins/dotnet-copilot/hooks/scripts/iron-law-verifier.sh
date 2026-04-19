#!/usr/bin/env bash
# PostToolUse hook: Programmatic Iron Law verification after Edit/Write.
# Inspired by AutoHarness (Lou et al., 2026) "harness-as-action-verifier" pattern:
# Code validates LLM output, feeds specific violation back for retry.
# Unlike security-reminder.sh (filename-based), this scans CODE CONTENT.

FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty')
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check C# files
[[ "$FILE_PATH" == *.cs ]] || exit 0
[[ -f "$FILE_PATH" ]] || exit 0

VIOLATIONS=""

# Helper: grep lines that are NOT comments (skip // comments and /// xml-doc)
check_violation() {
  local pattern="$1"
  grep -En "$pattern" "$FILE_PATH" 2>/dev/null | while IFS= read -r line; do
    content="${line#*:}"
    trimmed="${content#"${content%%[! 	]*}"}"
    # Skip single-line // comments and /// xml-doc comments
    if [[ "$trimmed" != //* ]] && [[ "$trimmed" != /\**  ]]; then
      echo "$line"
      break
    fi
  done
}

IS_TEST=false
if [[ "$FILE_PATH" == *Test*.cs ]] || [[ "$FILE_PATH" == *Tests*.cs ]] || [[ "$FILE_PATH" == */test/* ]] || [[ "$FILE_PATH" == */tests/* ]]; then
  IS_TEST=true
fi

# Iron Law #2: NEVER .Result or .Wait() on Task — sync-over-async deadlock
MATCH=$(check_violation '(\.Result\b|\.Wait\(\))')
if [[ -n "$MATCH" ]]; then
  # Heuristic: ignore PropertyInfo.GetValue().Result, IMethodResult, etc. by requiring Task-like context nearby
  if grep -qE '\b(Task|ValueTask|async)\b' "$FILE_PATH" 2>/dev/null; then
    LINE=$(echo "$MATCH" | cut -d: -f1)
    VIOLATIONS="${VIOLATIONS}\n- Iron Law #2 (line $LINE): .Result/.Wait() on Task — sync-over-async deadlock risk. Use await"
  fi
fi

# Iron Law #1: float/double for money — field/property named price/amount/etc
MATCH=$(check_violation '(public|private|protected|internal)[[:space:]]+(static[[:space:]]+)?(float|double)[[:space:]]+(Price|Amount|Cost|Total|Balance|Fee|Rate|Charge|Payment|Salary|Wage|Budget|Revenue|Discount)[A-Za-z]*[[:space:]]*[\{;=]')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #1 (line $LINE): float/double used for money field — use decimal"
fi

# Iron Law #26: raw SQL string interpolation / concatenation in FromSqlRaw or ExecuteSqlRaw
MATCH=$(check_violation '(FromSqlRaw|ExecuteSqlRaw|ExecuteSqlRawAsync)\([[:space:]]*\$"')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #26 (line $LINE): Raw SQL with string interpolation — SQL injection risk. Use FromSqlInterpolated or parameters"
fi

# Iron Law #26: string.Format with SQL
MATCH=$(check_violation 'string\.Format\(.*(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #26 (line $LINE): string.Format in SQL — injection risk. Use parameterized queries"
fi

# Iron Law #31: DbContext registered as Singleton
MATCH=$(check_violation 'AddSingleton<[^>]*DbContext')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #31 (line $LINE): DbContext registered as Singleton — concurrency corruption. Use AddDbContext (Scoped)"
fi

# Iron Law #32: direct new HttpClient()
if ! $IS_TEST; then
  MATCH=$(check_violation 'new HttpClient\(')
  if [[ -n "$MATCH" ]]; then
    LINE=$(echo "$MATCH" | cut -d: -f1)
    VIOLATIONS="${VIOLATIONS}\n- Iron Law #32 (line $LINE): new HttpClient() — socket exhaustion. Use IHttpClientFactory"
  fi
fi

# Iron Law #27: weak password hashing
MATCH=$(check_violation '\b(MD5|SHA1)\.(Create|HashData|ComputeHash)')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #27 (line $LINE): MD5/SHA1 usage — insecure for passwords. Use PasswordHasher<T> or Rfc2898DeriveBytes"
fi

# Iron Law #17: CORS AllowAnyOrigin
MATCH=$(check_violation '\.AllowAnyOrigin\(\)')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  VIOLATIONS="${VIOLATIONS}\n- Iron Law #17 (line $LINE): AllowAnyOrigin() — CORS wide open. Allowlist explicit origins"
fi

# Iron Law #3: IDisposable not in using — bare new SqlConnection / FileStream / StreamReader
MATCH=$(check_violation '^[[:space:]]*(var|SqlConnection|FileStream|StreamReader|StreamWriter|HttpResponseMessage)[[:space:]]+[a-zA-Z_]+[[:space:]]*=[[:space:]]*new[[:space:]]+(SqlConnection|FileStream|StreamReader|StreamWriter)\b')
if [[ -n "$MATCH" ]]; then
  LINE=$(echo "$MATCH" | cut -d: -f1)
  # Only warn if "using" is not on the same line
  LINE_CONTENT=$(sed -n "${LINE}p" "$FILE_PATH")
  if [[ "$LINE_CONTENT" != *"using"* ]]; then
    VIOLATIONS="${VIOLATIONS}\n- Iron Law #3 (line $LINE): IDisposable without using — resource leak. Wrap in using/using var"
  fi
fi

if [ -n "$VIOLATIONS" ]; then
  cat >&2 <<MSG
IRON LAW VIOLATION(S) in $(basename "$FILE_PATH"):
$(echo -e "$VIOLATIONS")

Fix these before proceeding. These are non-negotiable constraints.
MSG
  exit 2
fi
