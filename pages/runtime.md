# Runtime Configuration

If you want to add jobs on runtime, this is possible too:

```elixir
Quantum.add_job("1 * * * *", fn -> :ok end)
```

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

## Jobs with Second granularity

It is possible to specify jobs with second granularity.
To do this the `schedule` parameter has to be provided with either a `%Crontab.CronExpression{extended: true, ...}` or
with a set `e` flag on the `e` sigil. (The sigil must be imported from `Crontab.CronExpression`)

The following example will put a tick into the `stdout` every second.

```elixir
import Crontab.CronExpression

job = %Quantum.Job{schedule: ~e[* * * * *], task: fn -> IO.puts "tick" end}
Quantum.add_job(:ticker, job)
```
