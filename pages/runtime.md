# Runtime Configuration

If you want to add jobs on runtime, this is possible too:

```elixir
import Crontab.CronExpression

YourApp.Scheduler.add_job({~e[1 * * * *], fn -> :ok end})
```

Add a named job at runtime:

```elixir
import Crontab.CronExpression

YourApp.Scheduler.new_job()
|> Quantum.Job.set_name(:ticker)
|> Quantum.Job.set_schedule(~e[1 * * * *])
|> Quantum.Job.set_task(fn -> :ok end)
|> YourApp.Scheduler.add_job()
```

Deactivate a job, i.e. it will not be performed until job is activated again:
```elixir
YourApp.Scheduler.deactivate_job(:ticker)
```

Activate an inactive job:
```elixir
YourApp.Scheduler.activate_job(:ticker)
```

Run a job once outside of normal schedule:
```elixir
YourApp.Scheduler.run_job(:ticker)
```

Find a job:
```elixir
YourApp.Scheduler.find_job(:ticker)
# %Quantum.Job{...}
```

Delete a job:
```elixir
YourApp.Scheduler.delete_job(:ticker)
# %Quantum.Job{...}
```

## Jobs with Second granularity

It is possible to specify jobs with second granularity.
To do this the `schedule` parameter has to be provided with either a `%Crontab.CronExpression{extended: true, ...}` or
with a set `e` flag on the `e` sigil. (The sigil must be imported from `Crontab.CronExpression`)

The following example will put a tick into the `stdout` every second.

```elixir
import Crontab.CronExpression

YourApp.Scheduler.new_job()
|> Quantum.Job.set_name(:ticker)
|> Quantum.Job.set_schedule(~e[1 * * * *]e)
|> Quantum.Job.set_task(fn -> IO.puts "tick" end)
|> YourApp.Scheduler.add_job()
```
