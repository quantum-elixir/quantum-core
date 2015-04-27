# Quantum

[Cron](https://en.wikipedia.org/wiki/Cron)-like job scheduler for [Elixir](http://elixir-lang.org/) applications.

## Setup

To use this plug in your projects, edit your mix.exs file and add the project as a dependency:

```elixir
defp deps do
  [
    { :quantum, ">= 1.0.0" }
  ]
end
```

## Usage

```elixir
Quantum.cron("0 18-6/2 * * *", fn -> IO.puts("it's late") end)
Quantum.cron("@daily", &backup/0)
```

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
