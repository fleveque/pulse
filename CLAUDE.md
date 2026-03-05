# CLAUDE.md

## Build and Development Commands

```bash
# Start development server
mix phx.server

# Start with interactive shell
iex -S mix phx.server

# Run all tests
mix test

# Run a specific test file
mix test test/pulse_web/controllers/page_controller_test.exs

# Run a specific test by line number
mix test test/pulse_web/controllers/page_controller_test.exs:4

# Format code
mix format

# Check formatting
mix format --check-formatted

# Install dependencies
mix deps.get

# Compile
mix compile

# Compile with warnings as errors
mix compile --warnings-as-errors
```

## Architecture Overview

### OTP Supervision Tree

```
Pulse.Supervisor (one_for_one)
├── PulseWeb.Telemetry
├── DNSCluster
├── Phoenix.PubSub (name: Pulse.PubSub)
├── Registry (name: Pulse.PortfolioRegistry)
├── Pulse.PortfolioSupervisor (DynamicSupervisor)
├── Pulse.Nats.Connection (Gnat.ConnectionSupervisor)
├── Pulse.Nats.Consumer (GenServer)
└── PulseWeb.Endpoint
```

### Key Components

- **PortfolioWorker** (GenServer) — maintains live portfolio state per opted-in user
- **PortfolioSupervisor** (DynamicSupervisor) — starts/stops PortfolioWorkers on opt-in/out
- **PortfolioRegistry** (Registry) — looks up PortfolioWorker by slug
- **Nats.Connection** — supervised NATS connection via Gnat
- **Nats.Consumer** — subscribes to NATS events and dispatches to workers
- **DashboardLive** — real-time community dashboard (LiveView)
- **PortfolioLive** — individual portfolio page at `/p/:slug` (LiveView)

### NATS Events

Events are prefixed by environment (`prod.`, `beta.`, `dev.`):

- `{env}.portfolio.updated` — holdings changed
- `{env}.portfolio.opted_in` — user started sharing
- `{env}.portfolio.opted_out` — user stopped sharing
- `{env}.stock.price_updated` — stock price changed

### Configuration

- NATS host/port: `config :pulse, :nats, host: "...", port: 4222`
- Environment prefix: `config :pulse, :nats_env_prefix, "prod"`
- In production, set via env vars: `NATS_HOST`, `NATS_PORT`, `NATS_ENV_PREFIX`

## Deployment

Deployed via Kamal to `pulse.quantic.es` (production) and `beta-pulse.quantic.es` (beta).
