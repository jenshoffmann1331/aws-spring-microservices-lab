#!/usr/bin/env bash
set -euo pipefail

aws cloudformation deploy \
  --region eu-central-1 \
  --stack-name microservices-lab-dev-cfn-role \
  --template-file infra/cloudformation/iam/cfn-service-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM
