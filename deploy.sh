#!/bin/bash
# Pull latest code and restart services
# Usage: ./deploy.sh [service-name]
# Example: ./deploy.sh python-api   (rebuild one service)
# Example: ./deploy.sh              (rebuild all)

set -e

cd /home/ubuntu

echo "=== Pulling latest code ==="
for repo in mp-backend-node-service mp-backend-java-service mp-backend-python-service mp-infra; do
  echo "Pulling $repo..."
  cd "/home/ubuntu/$repo" && git pull origin main && cd /home/ubuntu
done

echo "=== Rebuilding containers ==="
cd /home/ubuntu/mp-infra

if [ -n "$1" ]; then
  echo "Rebuilding $1 only..."
  sudo docker compose up -d --build "$1"
else
  echo "Rebuilding all services..."
  sudo docker compose up -d --build
fi

echo "=== Status ==="
sudo docker compose ps
echo ""
echo "Health check: curl http://localhost/health"
