# Migrate to V2

## Scheduler

Instead of providing one global `Quantum` `GenServer`, every app has to provide its own `Scheduler` in V2. (Like for example `Ecto.Repo`)

This allows Umbrella Projects etc. to maintain their own quantum configuration without interfering with other apps.


**1: create `Scheduler`:**

```elixir
defmodule YourApp.Scheduler do
  use Quantum.Scheduler,
    otp_app: :your_app
end
```

**2: add `Scheduler` to your supervision tree:**
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

## Configuration

The configuration notations have been cleaned up. Those are the existing notations:

### Schedule Notations

1. `{:cron, "* * * * *"}` (Tuple of `:cron`, String) - Expression without second support
2. `{:extended, "* * * * * *"}` (Tuple of `:extended`, String) - Expression with second support
3. `"* * * * *"` (Any String) - Expression without second support

### Task Notations

1. `{Module, :func, [args]}` - Standard Way of specifying Tasks
2. `fn -> :some_anon_func end}` - Used for simple short tasks

### Configuration Syntax

```elixir
config :quantum, :your_app,
  jobs: [
    # Named Keyword Explicit Form
   [name: NAME, schedule: CONFIG_SCHEDULE_NOTATION, task: CONFIG_TASK_NOTATION, OTHER_FIELDS],

    # Unnamed Explicit Form
   [schedule: CONFIG_SCHEDULE_NOTATION, task: CONFIG_TASK_NOTATION, OTHER_FIELDS],
    # Short Form
   {CONFIG_SCHEDULE_NOTATION, CONFIG_TASK_NOTATION},
  ]
```

## Runtime Configuration

### Schedule Notations

Only the `Crontab.CronExpression` struct is supported. Use the sigil `~e[EXPRESSION]` for an easy way to define the schedule.

### Task Notations

1. `{Module, :func, [args]}` - Standard Way of specifying Tasks
2. `fn -> :some_anon_func end}` - Used for simple short tasks

## Job struct

The job struct should not be manipulated by hand. Please use the factory `YourApp.Scheduler.new_job` (`Quantum.Scheduler.new_job/1`) to create a new instance and the setters in `Quantum.Job` to manipulate the job.

The setter do not normalize values as in `v1`. The correct type has to be provided.

## Run Strategies

Instead of a `nodes` list, a run strategy can be provided. The nodes list is not supported anymore.
