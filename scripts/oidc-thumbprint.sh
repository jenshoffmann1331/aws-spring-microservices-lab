#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  ./oidc-thumbprint.sh https://token.actions.githubusercontent.com
#
# Output: SHA1 thumbprint of the top intermediate certificate (2nd cert) without colons.

OIDC_INPUT="${1:-https://token.actions.githubusercontent.com}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required but not installed." >&2
    exit 1
  }
}

require curl
require jq
require openssl

# If input is issuer URL (no /.well-known/openid-configuration), append it.
if [[ "$OIDC_INPUT" != *"/.well-known/openid-configuration" ]]; then
  DISCOVERY_URL="${OIDC_INPUT%/}/.well-known/openid-configuration"
else
  DISCOVERY_URL="$OIDC_INPUT"
fi

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "Discovery: $DISCOVERY_URL" >&2

# Fetch discovery doc
DISCOVERY_JSON="$tmpdir/discovery.json"
curl -fsSL --connect-timeout 5 --max-time 15 "$DISCOVERY_URL" -o "$DISCOVERY_JSON"

# Prefer jwks_uri host (your approach), fallback to issuer host.
JWKS_URL="$(jq -r '.jwks_uri // empty' "$DISCOVERY_JSON")"
ISSUER_URL="$(jq -r '.issuer // empty' "$DISCOVERY_JSON")"

if [[ -n "$JWKS_URL" ]]; then
  TARGET_URL="$JWKS_URL"
elif [[ -n "$ISSUER_URL" ]]; then
  TARGET_URL="$ISSUER_URL"
else
  echo "ERROR: Discovery doc contains neither 'jwks_uri' nor 'issuer'." >&2
  exit 1
fi

# Extract host from URL safely (handles https://host/path, host:port not expected here)
# shellcheck disable=SC2001
HOST="$(echo "$TARGET_URL" | sed -E 's#^[a-zA-Z]+://##' | sed -E 's#/.*$##' | sed -E 's#:[0-9]+$##')"

if [[ -z "$HOST" ]]; then
  echo "ERROR: Could not parse host from URL: $TARGET_URL" >&2
  exit 1
fi

echo "TLS host: $HOST (from $TARGET_URL)" >&2

CERT_FILE="${2:-github-oidc-intermediate.crt}"

# Extract 2nd certificate from chain (top intermediate)
openssl s_client \
  -connect "${HOST}:443" \
  -servername "$HOST" \
  -showcerts </dev/null 2>/dev/null \
| awk '/BEGIN CERTIFICATE/{i++} i==2{print} /END CERTIFICATE/{if(i==2) exit}' \
> "$CERT_FILE"

if [[ ! -s "$CERT_FILE" ]]; then
  echo "ERROR: Could not extract intermediate certificate from $HOST." >&2
  exit 1
fi

# Output thumbprint without colons (SHA1) for CloudFormation ThumbprintList
openssl x509 \
  -in "$CERT_FILE" \
  -fingerprint -sha1 -noout \
| cut -d'=' -f2 | tr -d ':'
