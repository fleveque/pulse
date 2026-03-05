# Pulse

Public portfolio showcase and community dashboard for the dividend-portfolio ecosystem. Built with Elixir/Phoenix LiveView to practice OTP patterns (GenServers, Supervisors, Registry).

## Services Architecture

```
                         Internet
                            |
              +-------------+-------------+
              |             |             |
        quantic.es    pulse.quantic.es  logos.quantic.es
              |             |             |
    +---------+--+  +-------+------+  +---+--------+
    |  Rails App |  | Pulse (this) |  | Logo       |
    |            |  |   Phoenix    |  | Service    |
    | - Auth     |  |   LiveView   |  | (Go)       |
    | - Radar    |  |              |  +------------+
    | - Holdings |  | - Public     |
    | - Buy Plan |  |   portfolios |
    +-----+------+  | - Community  |
          |         |   dashboard  |
          |         +------+-------+
          |                |
          +---+  +---------+
              |  |
          +---+--+---+
          |   NATS   |
          | JetStream|
          +----------+
```

**Rails App** (`quantic.es`) — main app with user auth, stock radar, transactions, dividends, and holdings management. Publishes events to NATS when portfolio data changes.

**Pulse** (`pulse.quantic.es`) — this app. Consumes NATS events and serves public portfolio pages and a real-time community dashboard. No database — state is held in-memory via GenServers and ETS.

**NATS** — lightweight messaging server (~10MB RAM). Runs as a Docker container on the same VPS. JetStream enabled for persistent event streams. Environment isolation via subject prefixes (`prod.`, `beta.`, `dev.`).

**Logo Service** (`logos.quantic.es`) — Go microservice for company logo images.

### NATS Event Flow

```
Rails publishes:
  {env}.portfolio.updated     {slug, holdings: [{symbol, quantity, avg_price}]}
  {env}.portfolio.opted_in    {slug, holdings}
  {env}.portfolio.opted_out   {slug}
  {env}.stock.price_updated   {symbol, price, change_percent}

Pulse consumes -> updates GenServer state -> pushes to LiveView via PubSub
```

## Phoenix App Architecture

### OTP Supervision Tree

```
Pulse.Supervisor (one_for_one)
|
+-- PulseWeb.Telemetry          Telemetry metrics
+-- DNSCluster                  DNS-based clustering (production)
+-- Phoenix.PubSub              Internal pub/sub for LiveView updates
|
+-- Pulse.PortfolioRegistry     Registry: slug -> worker PID lookup
+-- Pulse.PortfolioSupervisor   DynamicSupervisor for portfolio workers
|     |
|     +-- PortfolioWorker("alice")    GenServer: holds Alice's portfolio
|     +-- PortfolioWorker("bob")      GenServer: holds Bob's portfolio
|     +-- ...                         One per opted-in user
|
+-- Pulse.Nats.Connection       Supervised NATS connection (Gnat)
+-- Pulse.Nats.Consumer         Subscribes to NATS subjects, dispatches events
|
+-- PulseWeb.Endpoint           Phoenix HTTP server (Bandit)
```

### How Workers Operate

Each `PortfolioWorker` is a GenServer that:

1. **Starts** when a `portfolio.opted_in` event arrives — the `Nats.Consumer` tells `PortfolioSupervisor` to start a child
2. **Holds state** — current holdings, computed metrics (allocation percentages, total value, holding count)
3. **Updates** on `portfolio.updated` events — recomputes metrics and broadcasts to PubSub
4. **Serves reads** — LiveView pages call `PortfolioWorker.get_portfolio(slug)` via the Registry
5. **Stops** when a `portfolio.opted_out` event arrives — the supervisor terminates the child

The `PortfolioRegistry` allows O(1) lookup of worker processes by slug, so LiveView pages can find the right GenServer without querying a database.

### LiveView Pages

- **`/`** — `DashboardLive` — Community dashboard showing aggregate stats across all shared portfolios. Subscribes to PubSub `"dashboard"` topic for real-time updates.
- **`/p/:slug`** — `PortfolioLive` — Individual portfolio page. Subscribes to PubSub `"portfolio:{slug}"` for real-time updates when holdings change.

Both pages use server-rendered HTML via LiveView — no JavaScript framework needed. Updates are pushed over WebSocket automatically.

### OTP Patterns Used

| Pattern | Where | Purpose |
|---|---|---|
| **GenServer** | `PortfolioWorker` | Per-portfolio stateful process |
| **DynamicSupervisor** | `PortfolioSupervisor` | Start/stop workers at runtime |
| **Registry** | `PortfolioRegistry` | Name-based worker lookup |
| **Phoenix PubSub** | LiveView pages | Push updates to browser |
| **Supervised connection** | `Nats.Connection` | Auto-reconnecting NATS client |

## Development

### Dev Container (recommended)

The project includes a devcontainer configuration with NATS included. This is the easiest way to get the full event system running locally.

1. Open the project in VS Code or any devcontainer-compatible editor
2. Reopen in container (or `devcontainer up`)
3. NATS is automatically available at `nats:4222` inside the container
4. Forwarded ports: `4000` (Phoenix), `4222` (NATS), `8222` (NATS monitoring)

The NATS monitoring UI is available at `http://localhost:8222` to inspect connections, subjects, and JetStream streams.

### Local Setup (without devcontainer)

**Prerequisites:** Erlang 27.3+ and Elixir 1.18+ (managed via asdf, see `.tool-versions`). Optionally, a NATS server on port 4222.

```bash
mix setup          # Install deps, build assets
mix phx.server     # Start dev server at localhost:4000
iex -S mix phx.server  # Start with interactive Elixir shell
```

### Testing

```bash
mix test                           # Run all tests
mix test test/path/to/test.exs     # Run specific file
mix test test/path/to/test.exs:10  # Run specific test by line
```

### Code Quality

```bash
mix format                      # Format code
mix format --check-formatted    # Check formatting (CI)
mix compile --warnings-as-errors  # Strict compilation (CI)
mix precommit                   # Run all checks
```

## Deployment

Deployed via [Kamal](https://kamal-deploy.org/) to the same Hetzner ARM64 VPS as the Rails app.

| Environment | URL | Branch | Deploy command |
|---|---|---|---|
| Production | `pulse.quantic.es` | `main` | `kamal deploy` |
| Beta | `beta-pulse.quantic.es` | `beta` | `kamal deploy -d beta` |

Auto-deploys on CI success for `main` and `beta` branches.

### GitHub Secrets

The deploy workflow requires these repository secrets (`Settings > Secrets and variables > Actions`):

| Secret | Description |
|---|---|
| `SSH_PRIVATE_KEY` | Private key for SSH access to the VPS (same key as dividend-portfolio) |
| `KAMAL_REGISTRY_PASSWORD` | Docker registry (GHCR) password / personal access token |
| `SECRET_KEY_BASE` | Phoenix secret — generate with `mix phx.gen.secret` |

### Environment Variables

| Variable | Description |
|---|---|
| `SECRET_KEY_BASE` | Phoenix secret (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Hostname for URL generation |
| `PHX_SERVER` | Set to `true` to start the HTTP server |
| `PORT` | HTTP port (default: 4000) |
| `NATS_HOST` | NATS server hostname |
| `NATS_PORT` | NATS server port (default: 4222) |
| `NATS_ENV_PREFIX` | Event subject prefix (`prod`, `beta`, `dev`) |
