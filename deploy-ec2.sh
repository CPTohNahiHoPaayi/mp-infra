#!/bin/bash
# Deploy to EC2 from local machine
# Usage: ./deploy-ec2.sh           (rebuild all)
#        ./deploy-ec2.sh python-api (rebuild one service)
#        ./deploy-ec2.sh java-api python-api (rebuild specific services)

KEY="$(dirname "$0")/mp-key-ap-south-1.pem"
HOST="ubuntu@api.texttolearn.in"

SERVICE_ARGS="${*}"

ssh -i "$KEY" "$HOST" bash -s -- "$SERVICE_ARGS" <<'REMOTE'
set -e
cd /home/ubuntu

echo "=== Pulling latest code ==="
for repo in mp-backend-node-service mp-backend-java-service mp-backend-python-service mp-infra; do
  echo "  $repo..."
  cd "/home/ubuntu/$repo" && git pull origin main --ff-only 2>&1 | sed 's/^/    /' && cd /home/ubuntu
done

echo ""
echo "=== Rebuilding containers ==="
cd /home/ubuntu/mp-infra

if [ -n "$1" ]; then
  echo "  Services: $1"
  sudo docker compose up -d --build $1
else
  echo "  All services..."
  sudo docker compose up -d --build
fi

echo ""
echo "=== Status ==="
sudo docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
REMOTE
