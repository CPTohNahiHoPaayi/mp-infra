# mp-infra

Infrastructure and deployment configuration for the TextToLearn platform.

## Architecture

```
                         ┌─────────────────────────────┐
                         │     Vercel (Frontend)        │
                         │  mp-frontend-one.vercel.app  │
                         └──────────────┬───────────────┘
                                        │
                                        ▼
┌───────────────────────────────────────────────────────────────┐
│                  EC2 (ap-south-1) — Docker Compose            │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Caddy (Reverse Proxy + Auto-SSL)                       │  │
│  │  api.texttolearn.in :80/:443                            │  │
│  │                                                         │  │
│  │  /api/node/*   → node-api:3000   (strip prefix)        │  │
│  │  /api/java/*   → java-api:5001   (strip prefix)        │  │
│  │  /api/python/* → python-api:8000 (strip prefix)        │  │
│  │  /health       → 200 OK                                │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────────────┐ │
│  │  node-api    │ │  java-api    │ │  python-api            │ │
│  │  Express     │ │  Spring Boot │ │  FastAPI + ChromaDB    │ │
│  │  :3000       │ │  :5001       │ │  :8000                 │ │
│  │              │ │              │ │                        │ │
│  │  MongoDB     │ │  PostgreSQL  │ │  Embeddings (MiniLM)   │ │
│  │  (Atlas)     │ │  (Aiven)     │ │  Reranker (ms-marco)   │ │
│  │              │ │  Redis Cloud │ │  LLM (OpenRouter)      │ │
│  └──────────────┘ └──────────────┘ └────────────────────────┘ │
│                                                               │
│  ┌──────────────┐                                             │
│  │  chromadb    │                                             │
│  │  :8001       │                                             │
│  │  (vector DB) │                                             │
│  └──────────────┘                                             │
└───────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines all 5 services: caddy, node-api, java-api, python-api, chromadb |
| `Caddyfile` | Reverse proxy routes with auto-SSL for `api.texttolearn.in` |
| `.env` | Shared secrets consumed by all backend services (gitignored) |
| `.env.example` | Template for `.env` — copy and fill in secrets |
| `deploy.sh` | Runs **on EC2**: pulls repos, rebuilds containers |
| `dev.sh` | Runs **locally**: starts all services with hot-reload |
| `setup.sh` | First-time EC2 setup: installs Docker, clones repos, builds |
| `nginx/` | Legacy nginx config (unused — replaced by Caddy) |

## Services

### caddy
- **Image**: `caddy:2-alpine`
- **Ports**: 80, 443 (public)
- **Role**: Reverse proxy, automatic HTTPS via Let's Encrypt
- **Volumes**: `caddy_data` (certs), `caddy_config`

### node-api
- **Build**: `../mp-backend-node-service`
- **Port**: 3000 (internal)
- **Route**: `api.texttolearn.in/api/node/*`
- **Env**: `.env` (MongoDB, JWT, OpenAI, Gemini, YouTube)

### java-api
- **Build**: `../mp-backend-java-service`
- **Port**: 5001 (internal)
- **Route**: `api.texttolearn.in/api/java/*`
- **Env**: `.env` (PostgreSQL, Google OAuth, JWT, Gemini, Redis)

### python-api
- **Build**: `../mp-backend-python-service`
- **Port**: 8000 (internal)
- **Route**: `api.texttolearn.in/api/python/*`
- **Env**: `.env` (OpenRouter API key)

### chromadb
- **Image**: `chromadb/chroma:latest`
- **Port**: 8001 (internal)
- **Volume**: `chroma_data` (persisted vector data)

## Deployment

### From local machine

```bash
# Deploy all services
./deploy-ec2.sh

# Deploy specific service(s)
./deploy-ec2.sh python-api
./deploy-ec2.sh java-api python-api
```

The `deploy-ec2.sh` script (in project root) SSHs into EC2 and runs the deploy.

### On EC2 directly

```bash
ssh -i mp-key-ap-south-1.pem ubuntu@api.texttolearn.in
cd /home/ubuntu/mp-infra
./deploy.sh              # all services
./deploy.sh python-api   # one service
```

### Logs

```bash
# All services
ssh -i mp-key-ap-south-1.pem ubuntu@api.texttolearn.in \
  "cd /home/ubuntu/mp-infra && sudo docker compose logs --tail=50"

# Specific service
ssh -i mp-key-ap-south-1.pem ubuntu@api.texttolearn.in \
  "cd /home/ubuntu/mp-infra && sudo docker compose logs --tail=50 python-api"

# Follow in real-time
ssh -i mp-key-ap-south-1.pem ubuntu@api.texttolearn.in \
  "cd /home/ubuntu/mp-infra && sudo docker compose logs -f python-api"
```

## Local Development

```bash
bash dev.sh
```

Starts all 4 services with hot-reload:
- Frontend: http://localhost:5173
- Java API: http://localhost:5001
- Node API: http://localhost:3000
- Python API: http://localhost:8000

## First-Time Server Setup

```bash
# SSH into a fresh Ubuntu EC2 instance
ssh -i mp-key-ap-south-1.pem ubuntu@<ip>

# Run setup
curl -s https://raw.githubusercontent.com/CPTohNahiHoPaayi/mp-infra/main/setup.sh | bash

# Fill in secrets
nano /home/ubuntu/mp-infra/.env

# Start services
cd /home/ubuntu/mp-infra && sudo docker compose up -d --build
```

## Environment Variables

See `.env.example` for all required variables. Key groups:

| Group | Variables | Used by |
|-------|-----------|---------|
| MongoDB | `MONGODB_URI`, `DBUsername`, `DBPassword` | node-api |
| PostgreSQL | `POSTGRES_URL`, `POSTGRES_USER`, `POSTGRES_PASS` | java-api |
| Google OAuth | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` | java-api |
| JWT | `JWT_SECRET` | node-api, java-api |
| Redis | `REDIS_URL` | java-api |
| Gemini | `GEMINI_API_KEYS` | java-api |
| OpenRouter | `OPEN_ROUTER_API_KEY` | python-api |
| CORS | `CORS_ORIGINS` | java-api |

## CORS

Each backend handles its own CORS headers:
- **node-api**: `cors()` — allows all origins
- **java-api**: `CORS_ORIGINS` env var (comma-separated)
- **python-api**: Hardcoded allowlist in `main.py`

Caddy does **not** add CORS headers to avoid duplicates.

## Domain & SSL

- Domain: `api.texttolearn.in`
- SSL: Automatic via Caddy (Let's Encrypt)
- Frontend: `mp-frontend-one.vercel.app` (auto-deploys on push to main)
