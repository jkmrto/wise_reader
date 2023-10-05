import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wise_reader, WiseReaderWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KahWyMBoy09r0ZxkS7yd12rUvpxaSf8Q+eas6UTogg+Z3EYeNUHrsGkexJq9Ke4C",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
