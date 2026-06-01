import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :such_gallery_elixir, SuchGalleryElixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "khRXb6z8kuyEg4hG8DmPGlT8er+DMwA8Gewx8ZOVr31sE1TioEtmHuo2EvqDrrn6",
  server: false

config :such_gallery_elixir, SuchGalleryElixir.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "such_gallery_elixir_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
