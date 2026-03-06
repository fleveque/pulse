import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pulse, PulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "u548Bl1XWyyhSWuEGOrZKuZcGuFZkHltdtuk28XUqgjrtsgrTB+qBlCK1ychPBXu",
  server: false

# NATS connection (test uses localhost, connection errors are expected)
config :pulse, :nats,
  host: "localhost",
  port: 4222

config :pulse, :nats_env_prefix, "test"

# Use separate data directory so tests don't wipe dev data
config :pulse, :data_dir, "priv/data/test"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
