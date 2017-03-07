# Error Handling

Cron Tasks can be supervised normally through a `Task.Supervisor`.

The error handling can be implemented via a normal OTP Supervisor Tree.

## Setup

* Start `Task.Supervisor`
* Add Functions to call

### Example Module

```elixir
defmodule Acme do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Our new supervisor
      supervisor(Task.Supervisor, [[name: Acme.TaskSupervisor, restart: :transient]]),
    ]

    opts = [strategy: :one_for_one, name: Acme.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def execute_anonymous_function do
    {:ok, _pid} = Task.Supervisor.start_child(Acme.TaskSupervisor, fn ->
      Logger.info("Do something")
    end)
  end

  def execute_named_function do
    {:ok, _pid} = Task.Supervisor.start_child(Acme.TaskSupervisor, &my_func_to_call/0)
  end

  def my_func_to_call do
    Logger.info("Do something")
  end
end
```

### Example Config

```elixir
use Mix.Config

config :quantum, acme: [
  cron: ["* * * * *": {Acme, :execute_anonymous_function},
         "* * * * *": {Acme, :execute_named_function}]]
```
