import Config

config :logger, :console, metadata: [:all, :crash_reason]
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
