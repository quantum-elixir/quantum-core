# Configuration

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :quantum, :your_app,
  cron: [
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

## Release managers
[conform](https://github.com/bitwalker/conform) /
[exrm](https://github.com/bitwalker/exrm) /
[edeliver](https://github.com/boldpoker/edeliver))

Please note that the following config notation is not supported by release managers.

```elixir
{"* * * * *", fn -> :anonymous_function end}
```

## Named Jobs

You can define named jobs in your config like this:

```elixir
config :quantum, :your_app,
  cron: [
    news_letter: [
      schedule: "@weekly",
      task: {Heartbeat, :send, [:arg1]},
    ]
  ]
```

Possible options:
- `schedule` cron schedule, ex: `"@weekly"` / `"1 * * * *"` / `{:cron, "1 * * * *"}` or `{:extended, "1 * * * *"}`
- `task` function to be performed, ex: `{Heartbeat, :send, []}` or `fn -> :something end`
- `nodes` nodes list the task should be run on, default: `[node()]`
- `overlap` set to false to prevent next job from being executed if previous job is still running, default: `true`

It is possible to control the behavior of jobs at runtime.
For runtime configuration, job names are not restricted to be atoms.
Atoms are allowed as job names.

## Override default settings

The default job settings can be configured as shown in the example below.
So if you have a lot of jobs and do not want to override the
default setting in every job, you can set them globally.

```elixir
config :quantum, :your_app,
  default_schedule: "* * * * *",
  default_nodes: [:app1@myhost],
  default_overlap: false,
  default_timezone: :utc,
  cron: [
    # Your cronjobs
  ]
```

## Jobs with Second granularity

It is possible to specify jobs with second granularity.
To do this the `schedule` parameter has to be provided with a `{:extended, "1 * * * *"}` expression.

With Sigil:

```elixir
import Crontab.CronExpression

config :quantum, :your_app,
  cron: [
    news_letter: [
      schedule: {"*/2", true}, # Runs every two seconds
      task: {Heartbeat, :send, [:arg1]}
    ]
  ]
```

## GenServer timeout

Sometimes, you may come across GenServer timeout errors esp. when you have
too many jobs or high load. The default `GenServer.call` timeout is 5000.
You can override this default by specifying `timeout` setting in configuration.

```elixir
config :quantum, :your_app,
  timeout: 30_000
```

Or if you wish to wait indefinitely:

```elixir
config :quantum, :your_app,
  timeout: :infinity
```

## Cluster Nodes

If you need to run a job on a certain node you can define:

```elixir
config :quantum, :your_app,
  cron: [
    news_letter: [
      # your job config
      nodes: [:app1@myhost, "app2@myhost"]
    ]
  ]
```

**NOTE** If `nodes` is not defined current node is used and a job is performed on all nodes.


## Run Quantum as a global process

When you have a cluster of nodes, you may not want same jobs to be
generated on every single node, e.g. jobs involving db changes.

In this case, you may choose to run Quantum as a global process, thus
preventing same job being run multiple times because of it being generated
on multiple nodes. With the following configuration, Quantum will be run
as a globally unique process across the cluster.

```elixir
config :quantum, :your_app,
  global?: true,
  cron: [
    # Your cronjobs
  ]
```

## Timezone Support

Please note that Quantum uses **UTC timezone** and not local timezone.

To specify another default timezone, add the following `default_timezone` option to your configuration:

```elixir
config :quantum, :your_app,
  default_timezone: "America/Chicago",
  cron: [
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
