#!/usr/bin/env bash
set -euo pipefail

GITHUB_ORG=jenshoffmann1331
GITHUB_REPO=aws-spring-microservices-lab
GITHUB_BRANCH=main

OIDC_ARN="$(aws cloudformation describe-stacks \
  --region eu-central-1 \
  --stack-name github-identity-provider \
  --query "Stacks[0].Outputs[?OutputKey=='OidcProviderArn'].OutputValue" \
  --output text)"

CFN_ROLE_ARN="$(aws cloudformation describe-stacks \
  --region eu-central-1 \
  --stack-name microservices-lab-dev-cfn-role \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFormationServiceRoleArn'].OutputValue" \
  --output text)"

aws cloudformation deploy \
  --region eu-central-1 \
  --stack-name microservices-lab-dev-github-deploy-role \
  --template-file infra/cloudformation/iam/github-deploy-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    OidcProviderArn="$OIDC_ARN" \
    CloudFormationServiceRoleArn="$CFN_ROLE_ARN" \
    GitHubOrg="${GITHUB_ORG}" \
    GitHubRepo="${GITHUB_REPO}" \
    GitHubBranch="${GITHUB_BRANCH}"
