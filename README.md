# Quantum

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/).

[![Hex.pm Version](http://img.shields.io/hexpm/v/quantum.svg)](https://hex.pm/packages/quantum)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/quantum)
[![Build Status](https://travis-ci.org/quantum-elixir/quantum-core.svg?branch=master)](https://travis-ci.org/quantum-elixir/quantum-core)
[![Coverage Status](https://coveralls.io/repos/quantum-elixir/quantum-core/badge.svg?branch=master)](https://coveralls.io/r/quantum-elixir/quantum-core?branch=master)
[![Inline docs](http://inch-ci.org/github/quantum-elixir/quantum-core.svg)](http://inch-ci.org/github/quantum-elixir/quantum-core)
[![Hex.pm](https://img.shields.io/hexpm/dt/quantum.svg)](https://hex.pm/packages/quantum)

> **This README follows master, which may not be the currently published version**. Here are the
[docs for the latest published version of Quantum](https://hexdocs.pm/quantum/readme.html).

> :warning: **If you're using a version below `v2.2.6`, please update immediately.** :warning:
> See [Issue #321](https://github.com/quantum-elixir/quantum-core/issues/321) for more details.

## Setup

To use Quantum in your project, edit the `mix.exs` file and add Quantum to

**1. the list of dependencies:**
```elixir
defp deps do
  [{:quantum, "~> 2.3"},
   {:timex, "~> 3.0"}]
end
```

**2. and create a scheduler for your app:**
```elixir
defmodule YourApp.Scheduler do
  use Quantum.Scheduler,
    otp_app: :your_app
end
```

**3. and your application's supervision tree:**
```elixir
defmodule YourApp.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # This is the new line
      worker(YourApp.Scheduler, [])
    ]

    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Troubleshooting

To see more transparently what `quantum` is doing, configure the `logger` to display `:debug` messages.

```elixir
config :logger,
  level: :debug
```

If you want do use the logger in debug-level without the messages from quantum:

```elixir
config :your_app, YourApp.Scheduler,
  debug_logging: false
```

If you encounter any problems with `quantum`, please search if there is already an
  [open issue](https://github.com/quantum-elixir/quantum-core/issues) addressing the problem.

Otherwise feel free to [open an issue](https://github.com/quantum-elixir/quantum-core/issues/new). Please include debug logs.

## Migrate to V2

See the [Migration Guide](https://hexdocs.pm/quantum/migrate-v2.html).

## Usage

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :your_app, YourApp.Scheduler,
  jobs: [
    # Every minute
    {"* * * * *",      {Heartbeat, :send, []}},
    # Every 15 minutes
    {"*/15 * * * *",   fn -> System.cmd("rm", ["/tmp/tmp_"]) end},
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    {"0 18-6/2 * * *", fn -> :mnesia.backup('/var/backup/mnesia') end},
    # Runs every midnight:
    {"@daily",         {Backup, :backup, []}}
  ]
```

More details on the usage can be found in the [Documentation](https://hexdocs.pm/quantum/configuration.html)

## Contribution

This project uses the [Collective Code Construction Contract (C4)](http://rfc.zeromq.org/spec:42/C4/) for all code changes.

> "Everyone, without distinction or discrimination, SHALL have an equal right to become a Contributor under the
terms of this contract."

### tl;dr

1. Check for [open issues](https://github.com/quantum-elixir/quantum-core/issues) or [open a new issue](https://github.com/quantum-elixir/quantum-core/issues/new) to start a discussion around [a problem](https://www.youtube.com/watch?v=_QF9sFJGJuc).
2. Issues SHALL be named as "Problem: _description of the problem_".
3. Fork the [quantum-elixir repository on GitHub](https://github.com/quantum-elixir/quantum-core) to start making your changes
4. If possible, write a test which shows that the problem was solved.
5. Send a pull request.
6. Pull requests SHALL be named as "Solution: _description of your solution_"
7. Your pull request is merged and you are added to the [list of contributors](https://github.com/quantum-elixir/quantum-core/graphs/contributors)

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
