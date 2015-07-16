# Quantum

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/).

[![Hex.pm Version](http://img.shields.io/hexpm/v/quantum.svg)](https://hex.pm/packages/quantum)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/quantum)
[![Build Status](https://travis-ci.org/c-rack/quantum-elixir.png?branch=master)](https://travis-ci.org/c-rack/quantum-elixir)
[![Coverage Status](https://coveralls.io/repos/c-rack/quantum-elixir/badge.svg?branch=master)](https://coveralls.io/r/c-rack/quantum-elixir?branch=master)
[![License](https://img.shields.io/badge/license-Apache-brightgreen.svg?style=flat)](http://www.apache.org/licenses/LICENSE-2.0)

## Setup

To use Quantum in your projects, edit your `mix.exs` file and add Quantum as a dependency:

```elixir
defp deps do
  [{:quantum, ">= 1.3.0"}]
end
```

Then, add Quantum to the list of applications in your `mix.exs` file:

```elixir
def application do
  [applications: [:quantum]]
end
```

## Usage

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :quantum, cron: [
    # Every minute
    "* * * * *":      {"Heartbeat", :send},
    # Every 15 minutes
    "*/15 * * * *":   fn -> System.cmd("rm", ["/tmp/tmp_"] end,
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    "0 18-6/2 * * *": fn -> :mnesia.backup('/var/backup/mnesia') end,
    # Runs every midnight:
    "@daily":         &Backup.backup/0
]
```

or like this:

```elixir
config :quantum, cron: [
    # Every minute
    "* * * * *": {MyApp.MyModule, :my_method}
]
```

or you can provide module as a string:

```elixir
config :quantum, cron: [
    # Every minute
    "* * * * *": {"MyApp.MyModule", :my_method}
]
```

Or even use cron-like format (useful with conform/exrm/edeliver):
```elixir
config :quantum, cron: [
    # Every minute
    "* * * * * MyApp.MyModule.my_method"
]
```

If you want to add jobs on runtime, this is possible, too:

```elixir
Quantum.add_job("1 * * * *", fn -> :ok end)
```

### Crontab format

| Field        | Allowed values
| ------------ | --------------
| minute       | 0-59
| hour         | 0-23
| day of month | 1-31
| month        | 1-12 (or names)
| day of week  | 0-6 (0 is Sunday, or use names)

Names can also be used for the `month` and `day of week` fields.
Use the first three letters of the particular day or month (case does not matter).

*Note:* all times are defined in _UTC_ and not in local time. Make sure you
remember that when you run in your dev environment and wonder why your
crons are not firing.

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

## Contribution

This project uses the [C4.1 process](http://rfc.zeromq.org/spec:22) for all code changes.

> "Everyone, without distinction or discrimination, SHALL have an equal right to become a Contributor under the
terms of this contract."

### tl;dr

1. Check for [open issues](https://github.com/c-rack/quantum-elixir/issues) or [open a new issue](https://github.com/c-rack/quantum-elixir/issues/new) to start a discussion around [a problem](https://www.youtube.com/watch?v=_QF9sFJGJuc).
2. Issues SHALL be named as "Problem: _description of the problem_".
3. Fork the [quantum-elixir repository on Github](https://github.com/c-rack/quantum-elixir) to start making your changes
4. If possible, write a test which shows that the problem was solved.
5. Send a pull request.
6. Pull requests SHALL be named as "Solution: _description of your solution_"
7. Your pull request is merged and you are added to the [list of contributors](https://github.com/c-rack/quantum-elixir/graphs/contributors)

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
