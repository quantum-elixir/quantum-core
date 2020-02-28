# Configuration

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :your_app, YourApp.Scheduler,
  jobs: [
    # Every minute
    {"* * * * *",              {Heartbeat, :send, []}},
    {{:cron, "* * * * *"},     {Heartbeat, :send, []}},
    # Every second
    {{:extended, "* * * * *"}, {Heartbeat, :send, []}},
    # Every 15 minutes
    {"*/15 * * * *",           fn -> System.cmd("rm", ["/tmp/tmp_"]) end},
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    {"0 18-6/2 * * *",         fn -> :mnesia.backup('/var/backup/mnesia') end},
    # Runs every midnight:
    {"@daily",                 {Backup, :backup, []}}
  ]
```

## Persistent Storage

Persistent storage can be used to track jobs and last execution times over restarts.

**Note: If a storage is present, the jobs from the configuration will not be loaded to prevent conflicts.**

```elixir
config :your_app, YourApp.Scheduler,
  storage: Quantum.Storage.Implementation
```

### Storage Adapters

Storage implementations must implement the `Quantum.Storage` behaviour.

The following adapters are supported:

* [`PersistentEts`](https://hex.pm/packages/quantum_storage_persistent_ets)

## Release managers
(
[conform](https://github.com/bitwalker/conform) /
[distillery](https://github.com/bitwalker/distillery) /
[exrm](https://github.com/bitwalker/exrm) /
[edeliver](https://github.com/boldpoker/edeliver)
)

Please note that the following config notation **is not supported** by release managers.

```elixir
{"* * * * *", fn -> :anonymous_function end}
```

## Named Jobs

You can define named jobs in your config like this:

```elixir
config :your_app, YourApp.Scheduler,
  jobs: [
    news_letter: [
      schedule: "@weekly",
      task: {Heartbeat, :send, [:arg1]},
    ]
  ]
```

Possible options:
- `schedule` cron schedule, ex: `"@weekly"` / `"1 * * * *"` / `{:cron, "1 * * * *"}` or `{:extended, "1 * * * *"}`
- `task` function to be performed, ex: `{Heartbeat, :send, []}` or `fn -> :something end`
- `run_strategy` strategy on how to run tasks inside of cluster, default: `%Quantum.RunStrategy.Random{nodes: :cluster}`
- `overlap` set to false to prevent next job from being executed if previous job is still running, default: `true`

It is possible to control the behavior of jobs at runtime.

## Override default settings

The default job settings can be configured as shown in the example below.
So if you have a lot of jobs and do not want to override the
default setting in every job, you can set them globally.

```elixir
config :your_app, YourApp.Scheduler,
  schedule: "* * * * *",
  overlap: false,
  timezone: :utc,
  jobs: [
    # Your cronjobs
  ]
```

## Jobs with Second granularity

It is possible to specify jobs with second granularity.
To do this the `schedule` parameter has to be provided with a `{:extended, "1 * * * *"}` expression.

```elixir
config :your_app, YourApp.Scheduler,
  jobs: [
    news_letter: [
      schedule: {:extended, "*/2"}, # Runs every two seconds
      task: {Heartbeat, :send, [:arg1]}
    ]
  ]
```

## GenServer timeout

Sometimes, you may come across GenServer timeout errors esp. when you have
too many jobs or high load. The default `GenServer.call` timeout is 5000.
You can override this default by specifying `timeout` setting in configuration.

```elixir
config :your_app, YourApp.Scheduler,
  timeout: 30_000
```

Or if you wish to wait indefinitely:

```elixir
config :your_app, YourApp.Scheduler,
  timeout: :infinity
```

## Timezone Support

Please note that Quantum uses **UTC timezone** and not local timezone.

To specify another default timezone, add the following `timezone` option to your configuration:

```elixir
config :your_app, YourApp.Scheduler,
  timezone: "America/Chicago",
  jobs: [
    # Your cronjobs
  ]
```

Valid options are `:utc` or a timezone name such as `"America/Chicago"`. A full list of timezone names can be downloaded from https://www.iana.org/time-zones, or at https://en.wikipedia.org/wiki/List_of_tz_database_time_zones.

Timezones can also be configured on a per-job basis. This overrides the default Quantum timezone for a particular job. To set the timezone on a job, use the `timezone` key when creating the `Quantum.Job` structure.

```elixir
%Quantum.Job{
  # ...
  timezone: "America/New_York"
}
```
