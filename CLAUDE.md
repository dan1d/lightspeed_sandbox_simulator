# CLAUDE.md — Lightspeed Sandbox Simulator

Ruby gem that simulates POS operations against the Lightspeed K-Series API. Part of TheOwnerStack ecosystem.

## What This Does

Generates realistic sandbox data (categories, items, payment methods, orders, payments) against a Lightspeed K-Series business for development and testing. Used by AutoBooks to test the Lightspeed POS integration.

## Key Commands

```bash
bundle exec rspec                  # Run tests (275 examples, 0 failures)
COVERAGE=true bundle exec rspec    # With SimpleCov (100% line + branch)
bundle exec rubocop                # Lint (0 offenses)
gem build lightspeed_sandbox_simulator.gemspec  # Build gem
bin/simulate setup                 # Set up entities via API
bin/simulate generate --count 50   # Generate orders
```

## Architecture

```
lib/lightspeed_sandbox_simulator/
├── configuration.rb              # OAuth2 config, multi-merchant .env.json support
├── database.rb                   # Standalone ActiveRecord PostgreSQL management
├── seeder.rb                     # Idempotent DB seeder (4 business types)
├── generators/
│   ├── data_loader.rb            # DB-first with JSON fallback
│   ├── entity_generator.rb       # Setup categories/items/payment methods via API
│   └── order_generator.rb        # Realistic order generation with meal periods
├── models/                       # ActiveRecord models (7 models, UUID v7 PKs)
├── services/
│   ├── base_service.rb           # HTTParty client, Bearer auth, cursor pagination, audit
│   └── lightspeed/
│       ├── business_service.rb   # Business info, tax rates, floors
│       ├── menu_service.rb       # Categories + items CRUD
│       ├── order_service.rb      # Local/toGo orders, fetch with pagination
│       ├── payment_method_service.rb  # Payment methods CRUD
│       ├── payment_service.rb    # Payments CRUD with pagination
│       └── services_manager.rb   # Thread-safe lazy loader
├── data/                         # JSON seed data per business type
└── db/
    ├── migrate/                  # 8 migrations
    └── factories/                # FactoryBot factories
```

## Key Differences from Epos Now Simulator

| Aspect | Epos Now | Lightspeed |
|--------|----------|------------|
| Auth | Basic Auth (API key + secret) | OAuth2 Bearer token |
| HTTP client | RestClient | HTTParty |
| Pagination | Page-based (page/pageSize) | Cursor-based (cursor param) |
| Field naming | PascalCase | camelCase |
| IDs | Integer | int64 |
| Order types | Single endpoint | `/orders/local` + `/orders/toGo` |
| Base URL | `api.eposnowhq.com` | `api.lsk.lightspeed.app` |

## Lightspeed K-Series API

- **Base URL**: `https://api.lsk.lightspeed.app`
- **API Version**: V2 (`/api/v2/businesses/{businessId}/...`)
- **Auth**: `Authorization: Bearer {access_token}`
- **Pagination**: Cursor-based — response includes `"cursor"` field, pass as `?cursor=` param

## Quality Standards

- **100% line + branch coverage** (SimpleCov)
- **0 rubocop offenses**
- **TDD** — tests first, implementation second

## Do NOT

- Commit `.env` or `.env.json` files (contain credentials)
- Use `to_f` for financial calculations (use integer cents)
- Skip RSpec before committing
- Break the 100% coverage requirement
