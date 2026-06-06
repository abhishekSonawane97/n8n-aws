#!/usr/bin/env bash
set -e

aws sts get-caller-identity

# === Config ===
STACK_NAME="n8n-full-stack"
TEMPLATE_FILE="CF-n8n-infra.yaml"
AWS_REGION="ap-south-1"
ALLOWED_CIDR="0.0.0.0/0"
# Optional EC2 key pair name (must already exist in $AWS_REGION) to enable SSH with your PEM key.
# Leave empty to deploy without SSH key access. Override with: KEY_NAME=my-key ./cf-n8n.sh deploy
KEY_NAME="${KEY_NAME:-}"
# Optional public hostname + Cloudflare Tunnel token to serve n8n over HTTPS at that host.
# Both must be set together. Example:
#   N8N_HOSTNAME=n8n.example.com CLOUDFLARED_TOKEN=eyJ... ./cf-n8n.sh deploy
N8N_HOSTNAME="${N8N_HOSTNAME:-}"
CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"

function usage() {
  echo "Usage: $0 {deploy|update|destroy|status}"
  exit 1
}

cmd="$1"
if [ -z "$cmd" ]; then
  usage
fi

case "$cmd" in
  deploy|update)
    echo "[INFO] Deploying / Updating CloudFormation stack: $STACK_NAME"
    aws cloudformation deploy \
      --template-file "$TEMPLATE_FILE" \
      --stack-name "$STACK_NAME" \
      --region "$AWS_REGION" \
      --parameter-overrides AllowedCidr="$ALLOWED_CIDR" KeyName="$KEY_NAME" N8nHostname="$N8N_HOSTNAME" CloudflaredToken="$CLOUDFLARED_TOKEN" \
      --capabilities CAPABILITY_NAMED_IAM

    echo "[INFO] Waiting for stack to reach CREATE_COMPLETE / UPDATE_COMPLETE..."
    # Wait until creation or update completes
    if ! aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"; then
      aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
    fi

    echo "[INFO] Stack deployed/updated successfully"
    aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --region "$AWS_REGION" \
      --query "Stacks[0].Outputs"
    ;;
  destroy)
    echo "[INFO] Deleting CloudFormation stack: $STACK_NAME"
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"

    echo "[INFO] Waiting for stack to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"

    echo "[INFO] Stack deleted successfully"
    ;;
  status)
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
      && exit 0 || echo "Stack $STACK_NAME does not exist or cannot be described"
    ;;
  *)
    usage
    ;;
esac