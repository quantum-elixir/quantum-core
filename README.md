# Quantum

[![Financial Contributors on Open Collective](https://opencollective.com/quantum/all/badge.svg?label=financial+contributors)](https://opencollective.com/quantum)
[![.github/workflows/branch_main.yml](https://github.com/quantum-elixir/quantum-core/actions/workflows/branch_main.yml/badge.svg)](https://github.com/quantum-elixir/quantum-core/actions/workflows/branch_main.yml)
[![Coverage Status](https://coveralls.io/repos/quantum-elixir/quantum-core/badge.svg?branch=main)](https://coveralls.io/r/quantum-elixir/quantum-core?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/quantum.svg)](https://hex.pm/packages/quantum)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/quantum/)
[![Total Download](https://img.shields.io/hexpm/dt/quantum.svg)](https://hex.pm/packages/quantum)
[![License](https://img.shields.io/hexpm/l/quantum.svg)](https://github.com/quantum-elixir/quantum-core/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/quantum-elixir/quantum-core.svg)](https://github.com/quantum-elixir/quantum-core/commits/main)

> **This README follows main, which may not be the currently published version**. Here are the
[docs for the latest published version of Quantum](https://hexdocs.pm/quantum/readme.html).

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/).

## Setup

To use Quantum in your project, edit the `mix.exs` file and add `Quantum` to

**1. the list of dependencies:**
```elixir
defp deps do
  [
    {:quantum, "~> 3.0"}
  ]
end
```

**2. and create a scheduler for your app:**
```elixir
defmodule Acme.Scheduler do
  use Quantum, otp_app: :your_app
end
```

**3. and your application's supervision tree:**
```elixir
defmodule Acme.Application do
  use Application

  def start(_type, _args) do
    children = [
      # This is the new line
      Acme.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Acme.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Troubleshooting

To see more transparently what `quantum` is doing, configure the `logger` to display `:debug` messages.

```elixir
config :logger, level: :debug
```

If you want do use the logger in debug-level without the messages from quantum:

```elixir
config :acme, Acme.Scheduler,
  debug_logging: false
```

If you encounter any problems with `quantum`, please search if there is already an
  [open issue](https://github.com/quantum-elixir/quantum-core/issues) addressing the problem.

Otherwise feel free to [open an issue](https://github.com/quantum-elixir/quantum-core/issues/new). Please include debug logs.

## Usage

Configure your cronjobs in your `config/config.exs` like this:

```elixir
config :acme, Acme.Scheduler,
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

> "Everyone, without distinction or discrimination, SHALL have an equal right to become a Contributor under the terms of this contract."

### TL;DR

1. Check for [open issues](https://github.com/quantum-elixir/quantum-core/issues) or [open a new issue](https://github.com/quantum-elixir/quantum-core/issues/new) to start a discussion around [a problem](https://www.youtube.com/watch?v=_QF9sFJGJuc).
2. Issues SHALL be named as "Problem: _description of the problem_".
3. Fork the [quantum-elixir repository on GitHub](https://github.com/quantum-elixir/quantum-core) to start making your changes
4. If possible, write a test which shows that the problem was solved.
5. Send a pull request.
6. Pull requests SHALL be named as "Solution: _description of your solution_"
7. Your pull request is merged and you are added to the [list of contributors](https://github.com/quantum-elixir/quantum-core/graphs/contributors)

### Code Contributors

This project exists thanks to all the people who contribute.

[![Contributors](https://opencollective.com/quantum/contributors.svg?width=890&button=false)](https://github.com/quantum-elixir/quantum-core/graphs/contributors)

### Financial Contributors

Become a financial contributor and help us sustain our community. [[Contribute](https://opencollective.com/quantum/contribute)]

#### Individuals

[![Individuals](https://opencollective.com/quantum/individuals.svg?width=890)](https://opencollective.com/quantum)

#### Organizations

Support this project with your organization. Your logo will show up here with a link to your website. [[Contribute](https://opencollective.com/quantum/contribute)]

[![Organization0](https://opencollective.com/quantum/organization/0/avatar.svg)](https://opencollective.com/quantum/organization/0/website)
[![Organization1](https://opencollective.com/quantum/organization/1/avatar.svg)](https://opencollective.com/quantum/organization/1/website)
[![Organization2](https://opencollective.com/quantum/organization/2/avatar.svg)](https://opencollective.com/quantum/organization/2/website)
[![Organization3](https://opencollective.com/quantum/organization/3/avatar.svg)](https://opencollective.com/quantum/organization/3/website)
[![Organization4](https://opencollective.com/quantum/organization/4/avatar.svg)](https://opencollective.com/quantum/organization/4/website)
[![Organization5](https://opencollective.com/quantum/organization/5/avatar.svg)](https://opencollective.com/quantum/organization/5/website)
[![Organization6](https://opencollective.com/quantum/organization/6/avatar.svg)](https://opencollective.com/quantum/organization/6/website)
[![Organization7](https://opencollective.com/quantum/organization/7/avatar.svg)](https://opencollective.com/quantum/organization/7/website)
[![Organization8](https://opencollective.com/quantum/organization/8/avatar.svg)](https://opencollective.com/quantum/organization/8/website)
[![Organization9](https://opencollective.com/quantum/organization/9/avatar.svg)](https://opencollective.com/quantum/organization/9/website)

## Copyright and License

Copyright (c) 2015 Constantin Rack

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
