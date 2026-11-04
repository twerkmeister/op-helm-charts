#!/usr/bin/env bash
# usage: ./mkjwt.sh private.pem tenant-123
set -euo pipefail

KEY=${1:-private.pem}
SUB=${2:-tenant-123}
ISS="https://community.openproject.org"
EXP=$(( $(date +%s) + 3600 ))   # valid for 1 hour

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

header=$(printf '{"alg":"EdDSA","typ":"JWT"}' | b64url)
payload=$(printf '{"iss":"%s","sub":"%s","exp":%d}' "$ISS" "$SUB" "$EXP" | b64url)

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s.%s' "$header" "$payload" > "$tmp"

sig=$(openssl pkeyutl -sign -inkey "$KEY" -rawin -in "$tmp" | b64url)

echo "$header.$payload.$sig"