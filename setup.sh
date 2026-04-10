#!/bin/bash
# WORA setup script — run on any fresh Ubuntu server
# Usage: curl -s <raw-github-url>/setup.sh | bash

set -e

echo "=== Installing Docker ==="
sudo apt-get update -qq
sudo apt-get install -y -qq docker.io docker-compose-v2 git
sudo usermod -aG docker $USER

echo "=== Cloning repos ==="
cd /home/ubuntu
repos=(
  "mp-frontend"
  "mp-backend-node-service"
  "mp-backend-java-service"
  "mp-backend-python-service"
  "mp-infra"
)
for repo in "${repos[@]}"; do
  if [ ! -d "$repo" ]; then
    git clone "https://github.com/CPTohNahiHoPaayi/${repo}.git"
  else
    echo "$repo already exists, pulling latest..."
    cd "$repo" && git pull && cd ..
  fi
done

echo "=== Setting up environment ==="
cd /home/ubuntu/mp-infra
if [ ! -f .env ]; then
  cp .env.example .env
  echo "⚠️  Created .env from template — fill in your secrets!"
  echo "   Edit: nano /home/ubuntu/mp-infra/.env"
  exit 1
fi

echo "=== Building and starting services ==="
sudo docker compose up -d --build

echo "=== Done ==="
echo "Services running. Check: curl http://localhost/health"
