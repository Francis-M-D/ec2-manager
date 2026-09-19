# Architecture

## Overview

Multi-cloud EC2 instance manager, AWS-only today, structured for GCP/Azure/Oracle later.

```
┌─────────────┐      JWT       ┌──────────────────┐   Bearer token   ┌──────────────────┐
│   React     │ ─────────────▶ │   .NET 8 API     │ ───────────────▶ │  Python FastAPI   │
│  frontend   │ ◀───────────── │  (backend/)      │ ◀─────────────── │  (cloud-service/) │
└─────────────┘                └──────────────────┘                  └──────────────────┘
                                       │                                       │
                                       ▼                                       ▼
                                 ┌───────────┐                          ┌────────────┐
                                 │   MySQL   │                          │  AWS APIs  │
                                 │ (EF Core) │                          │  (boto3)   │
                                 └───────────┘                          └────────────┘
```

## Responsibilities

- **cloud-service** (Python/FastAPI/boto3): the only component that talks to AWS directly.
  Implements `CloudProvider` (list/start/stop instances, region discovery). AWS is implemented
  with STS AssumeRole (cross-account, refreshable credentials) or legacy static keys.
  GCP/Azure/Oracle are stubs that raise `NotImplementedError`, wired through the same
  `get_provider(cloud)` factory so swapping providers is a one-line change for callers.

- **backend** (.NET 8 Web API): owns users/auth (JWT), schedules, and audit logs (MySQL via
  EF Core). Never talks to AWS directly — always goes through `cloud-service` over HTTP,
  authenticated with a shared bearer secret (`EC2MANAGER_INTERNAL_API_KEY`). Enforces the
  DNS-tag policy at the API boundary and again when schedules fire (defense in depth; the
  Python service also enforces it at the point of the AWS call).

- **frontend** (React + Vite + TS + Tailwind): consumes the .NET API only, never cloud-service
  directly. TanStack Query handles caching/invalidation for instances, schedules, logs.

## DNS tag policy

Only instances tagged `DNS=Yes` (case-insensitive) may be started/stopped, manually or via
schedule. This is enforced in `cloud-service/app/providers/base.py::is_dns_enabled` and checked
right before every AWS `start_instances`/`stop_instances` call — never from a cache — so a tag
change takes effect on the very next action.

## Schedules

A schedule uses **either** a cron expression **or** windowed recurrence (`None`/`Daily`/`Weekly`
+ time of day + valid-from/valid-to), never both — validated in `ScheduleValidator`. A
`BackgroundService` (`ScheduleRunner`) polls every 15s, computes which enabled schedules are due,
and executes them through `cloud-service`, writing an audit log entry for every fire (success,
partial, or failed).

## Extending to a new cloud

1. Implement `CloudProvider` in `cloud-service/app/providers/<cloud>.py`.
2. Wire it into `factory.get_provider`.
3. Add an `authMode`/credential shape to the account config schema if it differs from AWS's
   `roleArn`/static-key shape.
4. No .NET or frontend changes are required unless you want cloud-specific UI (e.g. a cloud
   picker) — the internal API and DTOs are already cloud-agnostic.
