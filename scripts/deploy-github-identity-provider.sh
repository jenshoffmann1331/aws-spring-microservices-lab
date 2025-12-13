#!/usr/bin/env bash
set -euo pipefail

THUMBPRINT="$(./scripts/oidc-thumbprint.sh https://token.actions.githubusercontent.com)"

aws cloudformation deploy \
  --region eu-central-1 \
  --stack-name github-identity-provider \
  --template-file infra/cloudformation/iam/github-identity-provider.yaml \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ThumbprintSha1="$THUMBPRINT"
