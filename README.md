# FBR Digital Invoicing

Rails 8 application for Pakistan FBR digital invoicing — taxpayer portal, admin console, and FBR API integration.

## Features

- **Invoice lifecycle** — create, validate, async submit to FBR, PDF download, debit notes linked to original FBR invoices
- **Sandbox & production** — environment guardrails, scenario testing (admin), production token/profile requirements
- **Buyer companies & templates** — saved buyers, reusable invoice templates
- **FBR downloads** — IRIS lookup, sync, PDF for submitted invoices
- **Reports** — date-range summaries with CSV export and scheduled monthly email
- **Notifications & webhooks** — in-app alerts and HTTP webhooks on submit success/failure
- **Admin** — user approval, FBR API audit logs, cross-tenant reports
- **API** — `/api/v1/invoices`, buyer NTN validation, reference data
- **Background jobs** — Sidekiq for submission, validation, sync, cleanup, reports

## Requirements

- Ruby 3.4.7
- PostgreSQL
- Redis (Sidekiq)
- Node/Yarn (asset build, optional for dev)

## Setup

```bash
bundle install
yarn install # if using js/css bundling
cp .env.example .env   # configure DATABASE_URL, REDIS_URL, FBR tokens
bin/rails db:create db:migrate db:seed
bin/dev                # or: bin/rails server
```

## Environment variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` / `DATABASE_*` | PostgreSQL |
| `REDIS_URL` | Sidekiq & cache |
| `FBR_SANDBOX_TOKEN` | Fallback sandbox API token |
| `FBR_PRODUCTION_TOKEN` | Fallback production API token |
| `MAILER_FROM` | Outbound email address |

FBR tokens are stored **encrypted** per user in `fbr_configurations.token_ciphertext`.

## Roles

| Role | Access |
|------|--------|
| `admin` | Admin portal, Sidekiq, user approval |
| `taxpayer` | Full invoice management |
| `viewer` | Read-only portal |

New self-registrations require **admin approval** before portal access.

## Background jobs

```bash
bundle exec sidekiq
```

Scheduled via `config/schedule.rb` (whenever) or `config/sidekiq.yml`:

- `FbrSyncJob` — nightly IRIS sync
- `DashboardStatsJob` — cache dashboard stats
- `CleanupLogsJob` — prune FBR API logs (90 days)
- `MonthlyReportJob` — email tax summaries
- `AdminAlertsJob` — failed submission alerts

## API examples

```bash
# List invoices (session cookie auth)
GET /api/v1/invoices

# Create invoice
POST /api/v1/invoices
Content-Type: application/json

# Verify buyer NTN
POST /api/v1/buyer_validations
{ "ntn": "1234567-8" }
```

## Testing

```bash
bundle exec rspec
```

## Docker

```bash
docker build -t fbr-invoicing .
```

See `POSTMAN_TESTING.md` for FBR sandbox API examples.
