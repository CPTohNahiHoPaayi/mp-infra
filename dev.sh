#!/bin/bash
# Start all services locally in dev mode (hot-reload)
# Usage: bash dev.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

trap 'echo "Stopping all services..."; kill 0' EXIT

# Python RAG + RLM service (port 9000)
echo "Starting Python RAG + RLM service on :9000..."
(cd "$ROOT/mp-backend-python-service" && source venv/bin/activate && uvicorn app.main:app --reload --port 9000) &

# Node service (port 3000)
echo "Starting Node service on :3000..."
(cd "$ROOT/mp-backend-node-service" && PORT=3000 npm run dev) &

# Java service (port 5001)
echo "Starting Java service on :5001..."
(cd "$ROOT/mp-backend-java-service" && ./mvnw spring-boot:run) &

# Frontend (port 5173)
echo "Starting Frontend on :5173..."
(cd "$ROOT/mp-frontend" && npm run dev) &

echo ""
echo "All services starting..."
echo "  Frontend:   http://localhost:5173"
echo "  Java API:   http://localhost:5001"
echo "  Node API:   http://localhost:3000"
echo "  Python API: http://localhost:9000"
echo ""
echo "Press Ctrl+C to stop all services"

wait
