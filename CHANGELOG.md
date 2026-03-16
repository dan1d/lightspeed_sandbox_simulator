# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-16

### Added

- Initial release
- Lightspeed K-Series API v2 integration (OAuth2 Bearer auth, cursor-based pagination)
- Entity setup: categories, items, payment methods via API
- Order generation with 5 meal periods and weighted distributions
- Payment simulation with tender type selection
- Refund processing (configurable percentage)
- 4 business types: Restaurant, Cafe & Bakery, Bar & Nightclub, Retail General
- Multi-merchant support via `.env.json` configuration
- Optional PostgreSQL persistence (orders, payments, API requests, daily summaries)
- Thor CLI (`bin/simulate`) for all operations
- 275 test examples with 100% line and branch coverage
