# Lightspeed Sandbox Simulator

A Ruby gem for simulating POS operations against the **Lightspeed K-Series API**. Generates realistic orders, payments, and transaction data for development and testing.

## Features

- **Entity Setup** — Seed categories, menu items, and payment methods via the Lightspeed K-Series API
- **Order Generation** — Create realistic daily order patterns with meal periods, dining options, tips, and discounts
- **Payment Simulation** — Process payments with weighted tender selection (Cash, Credit Card, etc.)
- **Refund Processing** — Simulate refund flows at configurable percentages
- **Multi-Business-Type Support** — Restaurant, Cafe & Bakery, Bar & Nightclub, Retail General
- **Database Tracking** — Optional PostgreSQL persistence for orders, payments, API requests, and daily summaries
- **Thor CLI** — Command-line interface for all operations

## Installation

```ruby
gem 'lightspeed_sandbox_simulator'
```

Or install directly:

```bash
gem install lightspeed_sandbox_simulator
```

## Configuration

### Environment Variables

Create a `.env` file:

```bash
LIGHTSPEED_ACCESS_TOKEN=your_access_token
LIGHTSPEED_BUSINESS_ID=your_business_id
LIGHTSPEED_CLIENT_ID=your_client_id        # optional
LIGHTSPEED_CLIENT_SECRET=your_client_secret # optional
LIGHTSPEED_REFRESH_TOKEN=your_refresh_token # optional
LOG_LEVEL=INFO
TAX_RATE=20.0
LIGHTSPEED_TIMEZONE=America/New_York
```

### Multi-Merchant Support

Create a `.env.json` file for multiple merchants:

```json
[
  {
    "LIGHTSPEED_ACCESS_TOKEN": "token_1",
    "LIGHTSPEED_BUSINESS_ID": "business_1",
    "LIGHTSPEED_DEVICE_NAME": "Store A"
  },
  {
    "LIGHTSPEED_ACCESS_TOKEN": "token_2",
    "LIGHTSPEED_BUSINESS_ID": "business_2",
    "LIGHTSPEED_DEVICE_NAME": "Store B"
  }
]
```

### Ruby Configuration

```ruby
LightspeedSandboxSimulator.configure do |config|
  config.access_token = "your_access_token"
  config.business_id = "your_business_id"
end
```

## Usage

### CLI

```bash
# Set up menu entities (categories, items, payment methods)
bin/simulate setup --business-type restaurant

# Generate a day's worth of orders
bin/simulate generate --count 50 --business-type restaurant

# Generate a realistic day (volume based on day-of-week)
bin/simulate generate --realistic --business-type cafe_bakery

# Generate a rush period
bin/simulate rush --period dinner --count 20

# List available merchants
bin/simulate merchants

# Database operations (optional)
bin/simulate db:create
bin/simulate db:migrate
bin/simulate db:seed --business-type all
```

### Ruby API

```ruby
require "lightspeed_sandbox_simulator"

config = LightspeedSandboxSimulator::Configuration.new
config.access_token = "your_token"
config.business_id = "your_business_id"

# Set up entities
generator = LightspeedSandboxSimulator::Generators::EntityGenerator.new(
  config: config,
  business_type: :restaurant
)
result = generator.setup_all
# => { categories: [...], items: [...], payment_methods: [...] }

# Generate orders
order_gen = LightspeedSandboxSimulator::Generators::OrderGenerator.new(
  config: config,
  business_type: :restaurant,
  refund_percentage: 5
)
orders = order_gen.generate_today(count: 50)

# Use services directly
manager = LightspeedSandboxSimulator::Services::Lightspeed::ServicesManager.new(
  config: config
)
manager.menu.list_categories
manager.menu.create_item(name: "Espresso", price: 3.50, category_id: 1)
manager.orders.create_local_order(items: [{ item_id: 1, quantity: 2 }], table_number: 5)
manager.payments.create_payment(order_id: 100, amount: 25.50, payment_method_id: 1)
manager.business.fetch_business
```

## Business Types

| Type | Key | Categories |
|------|-----|------------|
| Restaurant | `:restaurant` | Appetizers, Entrees, Sides, Desserts, Beverages |
| Cafe & Bakery | `:cafe_bakery` | Hot Drinks, Cold Drinks, Pastries, Sandwiches, Snacks |
| Bar & Nightclub | `:bar_nightclub` | Beer, Wine, Cocktails, Spirits, Bar Food |
| Retail General | `:retail_general` | Electronics, Clothing, Home, Sports, Accessories |

## Order Generation Details

Orders are distributed across five meal periods with realistic weights:

| Period | Weight | Items per Order |
|--------|--------|-----------------|
| Breakfast | 15% | 1–3 |
| Lunch | 30% | 2–4 |
| Happy Hour | 10% | 2–4 |
| Dinner | 35% | 3–6 |
| Late Night | 10% | 1–3 |

Dining options (eat-in, takeaway, delivery) vary by period. Tips and discounts are calculated with configurable probability distributions.

## Database (Optional)

PostgreSQL tracking is optional. When configured, the gem persists:

- **API Requests** — Full audit log of all Lightspeed API calls
- **Simulated Orders** — Order details with meal period, dining option, amounts
- **Simulated Payments** — Payment records with tender type and amounts
- **Daily Summaries** — Aggregated daily stats with breakdowns
- **Business Types, Categories, Items** — Seeded reference data

```bash
# Set DATABASE_URL in .env or .env.json
DATABASE_URL=postgres://localhost:5432/lightspeed_sandbox

bin/simulate db:create
bin/simulate db:migrate
bin/simulate db:seed --business-type all
```

## Lightspeed K-Series API

This gem targets the [Lightspeed K-Series (L-Series) API](https://developers.lightspeedhq.com/):

- **Base URL**: `https://api.lsk.lightspeed.app`
- **Auth**: OAuth2 Bearer token
- **Pagination**: Cursor-based
- **API Version**: V2

### Endpoints Used

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v2/businesses/{id}` | Business info |
| GET | `/api/v2/businesses/{id}/menu/categories` | List categories |
| POST | `/api/v2/businesses/{id}/menu/categories` | Create category |
| GET | `/api/v2/businesses/{id}/menu/items` | List items |
| POST | `/api/v2/businesses/{id}/menu/items` | Create item |
| GET | `/api/v2/businesses/{id}/payment-methods` | List payment methods |
| POST | `/api/v2/businesses/{id}/payment-methods` | Create payment method |
| POST | `/api/v2/businesses/{id}/orders/local` | Create dine-in order |
| POST | `/api/v2/businesses/{id}/orders/toGo` | Create takeout order |
| GET | `/api/v2/businesses/{id}/orders` | Fetch orders |
| POST | `/api/v2/businesses/{id}/payments` | Create payment |
| GET | `/api/v2/businesses/{id}/payments` | Fetch payments |
| GET | `/api/v2/businesses/{id}/tax-rates` | List tax rates |
| GET | `/api/v2/businesses/{id}/floorplans` | List floor plans |

## Development

```bash
bundle install
bundle exec rspec                  # Run tests (275 examples)
COVERAGE=true bundle exec rspec    # With coverage report (100% line + branch)
bundle exec rubocop                # Lint (0 offenses)
```

## License

[MIT](LICENSE)
