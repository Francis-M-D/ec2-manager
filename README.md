# EC2 Manager

Multi-cloud instance manager — AWS supported today, architected for GCP/Azure/Oracle later.

- `cloud-service/` — Python 3.11 FastAPI + boto3. All direct AWS operations.
- `backend/` — .NET 8 Web API. Auth, schedules, audit logs. Calls `cloud-service` over HTTP.
- `frontend/` — React 18 + Vite + TypeScript + Tailwind. Dashboard, schedules, logs UI.
- `infra/` — Dockerfiles + docker-compose.
- `docs/` — architecture, env vars, encryption helper.

See `docs/architecture.md` for the full design and `docs/env-vars.md` before running anything.

## Quick start (Docker)

```bash
# 1. Generate encrypted account config
cd cloud-service
pip install -r requirements.txt --break-system-packages   # or use a venv
python generate_encrypted_config.py
# paste the two printed values into BOTH cloud-service/.env and backend/.env
# (copy the .env.example files first)
cp .env.example .env   # then edit
cd ../backend && cp .env.example .env   # then edit
cd ../frontend && cp .env.example .env  # defaults are fine for local docker-compose

# 2. Bring everything up
cd ../infra
docker compose up --build
```

- Frontend: http://localhost:5173
- Backend Swagger: http://localhost:8000/swagger
- cloud-service docs: http://localhost:8001/docs

## Quick start (local dev, no Docker)

```bash
# Terminal 1 — cloud-service
cd cloud-service
pip install -r requirements.txt --break-system-packages
cp .env.example .env   # fill in values
uvicorn app.main:app --reload --port 8001

# Terminal 2 — backend (requires MySQL running locally and .NET 8 SDK)
cd backend
cp .env.example .env   # fill in values
dotnet ef database update   # first time only, after installing dotnet-ef
dotnet run

# Terminal 3 — frontend
cd frontend
npm install
npm run dev
```

## First run checklist

1. Each target AWS account needs an IAM role trusting the cloud-service host's identity, with
   `ec2:Describe*`, `ec2:StartInstances`, `ec2:StopInstances` permissions.
2. Tag every instance you want manageable with `DNS=Yes` — instances without this tag can be
   viewed but never started/stopped.
3. Register a user via the frontend's Register tab (or `POST /auth/register`) to get a JWT.

## Status / known limitations

- GCP, Azure, and Oracle providers are stubs (`NotImplementedError`) — only the interface and
  factory wiring exist, per the original spec.
- The `.NET` backend was hand-written in this environment without a `dotnet` SDK available to
  compile/test it — the Python service and React frontend were both installed, type-checked,
  and build-verified successfully, but **please run `dotnet build` yourself before deploying**
  and report back if anything doesn't compile so it can be fixed.
- EF Core migrations are not included — run `dotnet ef migrations add InitialCreate` and
  `dotnet ef database update` after installing the `dotnet-ef` tool.
