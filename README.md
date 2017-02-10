# Quantum

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/).

[![Hex.pm Version](http://img.shields.io/hexpm/v/quantum.svg)](https://hex.pm/packages/quantum)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/quantum)
[![Build Status](https://travis-ci.org/c-rack/quantum-elixir.svg?branch=master)](https://travis-ci.org/c-rack/quantum-elixir)
[![Coverage Status](https://coveralls.io/repos/c-rack/quantum-elixir/badge.svg?branch=master)](https://coveralls.io/r/c-rack/quantum-elixir?branch=master)
[![Inline docs](http://inch-ci.org/github/c-rack/quantum-elixir.svg)](http://inch-ci.org/github/c-rack/quantum-elixir)
[![Hex.pm](https://img.shields.io/hexpm/dt/quantum.svg)](https://hex.pm/packages/quantum)

------

* [Setup](#setup)
* [Usage](#usage)
  * [Named jobs](#named-jobs)
  * [Nodes](#nodes)
  * [Timezone](#timezone)
  * [Crontab format](#crontab-format)
  * [Special expressions](#special-expressions)
  * [Override default settings](#override-default-settings)
  * [GenServer timeout](#genserver-timeout)
  * [Run Quantum as a global process](#run-quantum-as-a-global-process)
* [Contribution](#contribution)
* [License](#license)

------

## Setup

To use Quantum in your project, edit the `mix.exs` file and add Quantum to both

**1. the list of dependencies:**
```elixir
defp deps do
  [{:quantum, ">= 1.9.0"}]
end
```

**2. and the list of applications:**
```elixir
def application do
  [applications: [:quantum]]
end
```

## Usage

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :quantum, :your_app,
  cron: [
    # Every minute
    "* * * * *":      {"Heartbeat", :send},
    # Every 15 minutes
    "*/15 * * * *":   fn -> System.cmd("rm", ["/tmp/tmp_"]) end,
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    "0 18-6/2 * * *": fn -> :mnesia.backup('/var/backup/mnesia') end,
    # Runs every midnight:
    "@daily":         &Backup.backup/0
  ]
```

or like this:

```elixir
config :quantum, :your_app,
  cron: [
    # Every minute
    "* * * * *": {MyApp.MyModule, :my_method}
  ]
```

or you can provide module as a string:

```elixir
config :quantum, :your_app,
  cron: [
    # Every minute
    "* * * * *": {"MyApp.MyModule", :my_method}
  ]
```

Or even use cron-like format (useful with
[conform](https://github.com/bitwalker/conform) /
[exrm](https://github.com/bitwalker/exrm) /
[edeliver](https://github.com/boldpoker/edeliver)):
```elixir
config :quantum, :your_app,
  cron: [
    # Every minute
    "* * * * * MyApp.MyModule.my_method"
  ]
```

If you want to add jobs on runtime, this is possible too:

```elixir
Quantum.add_job("1 * * * *", fn -> :ok end)
```

### Named jobs

Job struct:
```elixir
%Quantum.Job{
  name: :job_name, # is set automatically on adding a job
  schedule: "1 * * * *", # required
  task: {MyApp.MyModule, :my_method}, # required
  args: [:a, :b] # optional, default: []
  state: :active, # is used for internal purposes
  nodes: [:node@host], # default: [node()]
  overlap: false, # run even if previous job is still running?, default: true
  pid: nil, # PID of last executed task
  timezone: :utc # Timezone to run task in, defaults to Quantum default which is UTC
}
```

You can define named jobs in your config like this:

```elixir
config :quantum, :your_app,
  cron: [
    news_letter: [
      schedule: "@weekly",
      task: "MyApp.NewsLetter.send", # {MyApp.NewsLetter, :send} is supported too
      args: [:whatever]
    ]
  ]
```

Possible options:
- `schedule` cron schedule, ex: `"@weekly"` / `"1 * * * *"` / `~e[1 * * * *]` or `%Crontab.CronExpression{minute: [1]}`
- `task` function to be performed, ex: `"MyApp.MyModule.my_method"` or `{MyApp.MyModule, :my_method}`
- `args` arguments list to be passed to `task`
- `nodes` nodes list the task should be run on, default: `[node()]`
- `overlap` set to false to prevent next job from being executed if previous job is still running, default: `true`

It is possible to control the behavior of jobs at runtime.
For runtime configuration, job names are not restricted to be atoms.
Strings, atoms and charlists are allowed as job names.

Add a named job at runtime:

```elixir
job = %Quantum.Job{schedule: "* * * * *", task: fn -> IO.puts "tick" end}
Quantum.add_job(:ticker, job)
```

Deactivate a job, i.e. it will not be performed until job is activated again:
```elixir
Quantum.deactivate_job(:ticker)
```

Activate an inactive job:
```elixir
Quantum.activate_job(:ticker)
```

Find a job:
```elixir
Quantum.find_job(:ticker)
# %Quantum.Job{...}
```

Delete a job:
```elixir
Quantum.delete_job(:ticker)
# %Quantum.Job{...}
```

### Jobs with Second granularity

It is possible to specify jobs with second granularity.
To do this the `schedule` parameter has to be provided with either a `%Crontab.CronExpression{extended: true, ...}` or
with a set `e` flag on the `e` sigil. (The sigil must be imported from `Crontab.CronExpression`)

With Sigil:
```elixir
import Crontab.CronExpression

config :quantum, :your_app,
  cron: [
    news_letter: [
      schedule: ~e[*/2]e, # Runs every two seconds
      task: "MyApp.NewsLetter.send", # {MyApp.NewsLetter, :send} is supported too
      args: [:whatever]
    ]
  ]
```

With Struct:
```elixir
config :quantum, :your_app,
  cron: [
    news_letter: [
      schedule: %Crontab.CronExpression{extended: true, second: [5]}, # Runs every minute at second 5
      task: "MyApp.NewsLetter.send", # {MyApp.NewsLetter, :send} is supported too
      args: [:whatever]
    ]
  ]
```

The struct & sigil are documented here: https://hexdocs.pm/crontab/Crontab.CronExpression.html

### Nodes

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

### Timezone

Please note that Quantum uses **UTC timezone** and not local timezone by default.

To specify another timezone, add the following `timezone` option to your configuration:

```elixir
config :quantum, :your_app,
  cron: [
    # Your cronjobs
  ]

config :quantum,
  timezone: "America/Chicago"
```

Valid options are `:utc` or a timezone name such as `"America/Chicago"`. A full list of timezone names can be downloaded from https://www.iana.org/time-zones, or at https://en.wikipedia.org/wiki/List_of_tz_database_time_zones.

Timezones can also be configured on a per-job basis. This overrides the default Quantum timezone for a particular job. To set the timezone on a job, use the `timezone` key when creating the `Quantum.Job` structure.

```elixir
%Quantum.Job{
  # ...
  timezone: "America/New_York"
}
```

### Crontab format

| Field        | Allowed values
| ------------ | --------------
| minute       | 0-59
| hour         | 0-23
| day of month | 1-31
| month        | 1-12 (or names)
| day of week  | 0-6 (0 is Sunday, or use abbreviated names)

Names can also be used for the `month` and `day of week` fields.
Use the first three letters of the particular day or month (case does not matter).

### Special expressions

Instead of the first five fields, one of these special strings may be used:

| String      | Description
| ----------- | -----------
| `@annually` | Run once a year, same as `"0 0 1 1 *"` or `@yearly`
| `@daily`    | Run once a day, same as `"0 0 * * *"` or `@midnight`
| `@hourly`   | Run once an hour, same as `"0 * * * *"`
| `@midnight` | Run once a day, same as `"0 0 * * *"` or `@daily`
| `@monthly`  | Run once a month, same as `"0 0 1 * *"`
| `@reboot`   | Run once, at startup
| `@weekly`   | Run once a week, same as `"0 0 * * 0"`
| `@yearly`   | Run once a year, same as `"0 0 1 1 *"` or `@annually`

### Override default settings

The default job settings can be configured as shown in the example below.
So if you have a lot of jobs and do not want to override the
default setting in every job, you can set them globally.

```elixir
config :quantum,
  default_schedule: "* * * * *",
  default_args: ["my api key"],
  default_nodes: [:app1@myhost],
  default_overlap: false

config :quantum, :your_app,
  cron: [
    # Your cronjobs
  ]
```

### GenServer timeout

Sometimes, you may come across GenServer timeout errors esp. when you have
too many jobs or high load. The default `GenServer.call` timeout is 5000.
You can override this default by specifying `timeout` setting in configuration.

```elixir
config :quantum,
  timeout: 30_000
```

Or if you wish to wait indefinitely:

```elixir
config :quantum,
  timeout: :infinity
```

### Run Quantum as a global process

When you have a cluster of nodes, you may not want same jobs to be
generated on every single node, e.g. jobs involving db changes.

In this case, you may choose to run Quantum as a global process, thus
preventing same job being run multiple times because of it being generated
on multiple nodes. With the following configuration, Quantum will be run
as a globally unique process across the cluster.

```elixir
config :quantum,
  global?: true

config :quantum, :your_app,
  cron: [
    # Your cronjobs
  ]
```

## Contribution

This project uses the [Collective Code Construction Contract (C4)](http://rfc.zeromq.org/spec:42/C4/) for all code changes.

> "Everyone, without distinction or discrimination, SHALL have an equal right to become a Contributor under the
terms of this contract."

### tl;dr

1. Check for [open issues](https://github.com/c-rack/quantum-elixir/issues) or [open a new issue](https://github.com/c-rack/quantum-elixir/issues/new) to start a discussion around [a problem](https://www.youtube.com/watch?v=_QF9sFJGJuc).
2. Issues SHALL be named as "Problem: _description of the problem_".
3. Fork the [quantum-elixir repository on GitHub](https://github.com/c-rack/quantum-elixir) to start making your changes
4. If possible, write a test which shows that the problem was solved.
5. Send a pull request.
6. Pull requests SHALL be named as "Solution: _description of your solution_"
7. Your pull request is merged and you are added to the [list of contributors](https://github.com/c-rack/quantum-elixir/graphs/contributors)

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
