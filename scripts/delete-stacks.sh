#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Reliable CloudFormation stack deletion (sequential, with waits + diagnostics)
#
# Usage:
#   ./scripts/delete-stacks.sh --stacks-file scripts/stacks-dev.txt
#   ./scripts/delete-stacks.sh stack-a stack-b stack-c
#
# Env vars:
#   REGION=eu-central-1
#   AWS_PROFILE=...
#   CFN_ROLE_ARN=arn:aws:iam::...:role/...
#   CONTINUE_ON_ERROR=true|false
# -----------------------------------------------------------------------------

REGION="${REGION:-eu-central-1}"
ROLE_ARN="${CFN_ROLE_ARN:-}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-false}"

PROFILE_OPT=()
if [[ -n "${AWS_PROFILE:-}" ]]; then
  PROFILE_OPT=(--profile "$AWS_PROFILE")
fi

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }

aws_cfn() {
  aws "${PROFILE_OPT[@]}" --region "$REGION" cloudformation "$@"
}

stack_exists() {
  local stack="$1"
  aws_cfn describe-stacks --stack-name "$stack" >/dev/null 2>&1
}

stack_status() {
  local stack="$1"
  aws_cfn describe-stacks --stack-name "$stack" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true
}

wait_delete() {
  local stack="$1"

  log "WAIT: stack-delete-complete for $stack (can take a while, esp. EKS)..."

  # Normal path
  if aws_cfn wait stack-delete-complete --stack-name "$stack"; then
    log "OK: Deleted $stack"
    return 0
  fi

  # Race/Timing: stack can already be gone even if waiter failed
  if ! stack_exists "$stack"; then
    log "OK: $stack no longer exists (treat as deleted)"
    return 0
  fi

  # Real failure: stack still exists
  local status
  status="$(stack_status "$stack")"
  log "ERROR: Delete wait failed for $stack (status: ${status:-unknown})"

  # Best-effort events (never fail script because of event fetching)
  log "EVENTS: last 25 events for $stack"
  aws_cfn describe-stack-events --stack-name "$stack" \
    --max-items 25 \
    --query 'StackEvents[].[Timestamp,ResourceStatus,LogicalResourceId,ResourceType,ResourceStatusReason]' \
    --output table 2>/dev/null || log "WARN: Could not fetch stack events (maybe already gone or access denied)"

  return 1
}

delete_stack() {
  local stack="$1"

  if ! stack_exists "$stack"; then
    log "SKIP: Stack does not exist: $stack"
    return 0
  fi

  local status
  status="$(stack_status "$stack")"
  log "INFO: $stack current status: $status"

  # If already deleting, just wait
  if [[ "$status" == "DELETE_IN_PROGRESS" ]]; then
    log "INFO: $stack already deleting -> waiting..."
    wait_delete "$stack"
    return 0
  fi

  log "DELETE: Initiating delete-stack for $stack"

  if [[ -n "$ROLE_ARN" ]]; then
    aws_cfn delete-stack --stack-name "$stack" --role-arn "$ROLE_ARN"
  else
    aws_cfn delete-stack --stack-name "$stack"
  fi

  # If it vanishes immediately, we're done
  if ! stack_exists "$stack"; then
    log "OK: $stack disappeared immediately after delete request"
    return 0
  fi

  wait_delete "$stack"
}

usage() {
  cat <<EOF
Usage:
  $0 --stacks-file <file>
  $0 <stack1> <stack2> ...

Env vars:
  REGION=eu-central-1
  AWS_PROFILE=yourprofile
  CFN_ROLE_ARN=arn:aws:iam::...:role/...
  CONTINUE_ON_ERROR=true|false

Examples:
  REGION=eu-central-1 CFN_ROLE_ARN=arn:... ./scripts/delete-stacks.sh --stacks-file scripts/stacks-dev.txt
  ./scripts/delete-stacks.sh microservices-lab-dev-argocd microservices-lab-dev-eks microservices-lab-dev-network
EOF
}

STACKS=()

if [[ "${1:-}" == "--stacks-file" ]]; then
  file="${2:-}"
  if [[ -z "${file:-}" || ! -f "$file" ]]; then
    usage
    exit 2
  fi

  while IFS= read -r line; do
    # strip comments
    line="${line%%#*}"
    # trim
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    STACKS+=("$line")
  done < "$file"

  shift 2 || true
else
  STACKS=("$@")
fi

if [[ "${#STACKS[@]}" -eq 0 ]]; then
  usage
  exit 2
fi

log "START: deleting ${#STACKS[@]} stacks in order"
log "REGION=$REGION  ROLE_ARN=${ROLE_ARN:-<none>}  CONTINUE_ON_ERROR=$CONTINUE_ON_ERROR"

failures=0

for stack in "${STACKS[@]}"; do
  log "----------------------------------------"
  log "STEP: delete $stack"
  if delete_stack "$stack"; then
    :
  else
    failures=$((failures + 1))
    if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
      log "WARN: continuing despite failure (failures=$failures)"
    else
      log "ABORT: stopping on first failure (failures=$failures)"
      exit 1
    fi
  fi
done

log "DONE: delete sequence complete (failures=$failures)"
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
