# Quantum

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/).

[![Hex.pm Version](http://img.shields.io/hexpm/v/quantum.svg)](https://hex.pm/packages/quantum)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/quantum)
[![Build Status](https://travis-ci.org/c-rack/quantum-elixir.png?branch=master)](https://travis-ci.org/c-rack/quantum-elixir)
[![Coverage Status](https://coveralls.io/repos/c-rack/quantum-elixir/badge.svg?branch=master)](https://coveralls.io/r/c-rack/quantum-elixir?branch=master)

## Setup

To use Quantum in your projects, edit your `mix.exs` file and add Quantum as a dependency:

```elixir
defp deps do
  [{:quantum, ">= 1.2.0"}]
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
    "* * * * *": fn -> IO.puts("every minute") end,
    "*/2 * * * *": fn -> IO.puts("every two minutes") end,
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    "0 18-6/2 * * *": fn -> IO.puts("it's late") end,
    # Runs every midnight:
    "@daily": &backup/0
]
```

If you want to add jobs on runtime, this is possible, too:

```elixir
Quantum.add_job("1 * * * *", fn -> :ok end)
```

## Contribution Process

This project uses the [C4.1 process](http://rfc.zeromq.org/spec:22) for all code changes.

> "Everyone, without distinction or discrimination, SHALL have an equal right to become a Contributor under the
terms of this contract."

### tl;dr

1. Check for [open issues](https://github.com/c-rack/quantum-elixir/issues) or [open a new issue](https://github.com/c-rack/quantum-elixir/issues/new) to start a discussion around a feature idea or a bug
2. Fork the [quantum-elixir repository on Github](https://github.com/c-rack/quantum-elixir) to start making your changes
3. Write a test which shows that the bug was fixed or that the feature works as expected
4. Send a pull request
5. Your pull request is merged and you are added to the [list of contributors](https://github.com/c-rack/quantum-elixir/graphs/contributors)

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
