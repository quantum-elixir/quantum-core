# Telemetry

Since version [`3.2.0`](https://github.com/quantum-elixir/quantum-core/releases/tag/v3.2.0) `quantum` supports [`:telemetry`](https://hexdocs.pm/telemetry) metrics.

<!--
  large parts of this docs are copied from https://raw.githubusercontent.com/phoenixframework/phoenix/master/guides/telemetry.md
  thanks phoenix :heart:
-->

## Overview

The [`:telemetry`](https://hexdocs.pm/telemetry) library allows you to emit events at various stages of an application's lifecycle. You can then respond to these events by, among other things, aggregating them as metrics and sending the metrics data to a reporting destination.

Telemetry stores events by their name in an ETS table, along with the handler for each event. Then, when a given event is executed, Telemetry looks up its handler and invokes it.

## Telemetry Events

Many Elixir libraries (including Quantum) are already using
the [`:telemetry`](http://hexdocs.pm/telemetry) package as a
way to give users more insight into the behavior of their
applications, by emitting events at key moments in the
application lifecycle.

A Telemetry event is made up of the following:

  * `name` - A string (e.g. `"my_app.worker.stop"`) or a
    list of atoms that uniquely identifies the event.

  * `measurements` - A map of atom keys (e.g. `:duration`)
    and numeric values.

  * `metadata` - A map of key/value pairs that can be used
    for tagging metrics.

### A Quantum Example

Here is an example of an event from your endpoint:

* `[:quantum, :job, :stop]` - dispatched whenever a job
  execution is done

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}`

This means that after each job execution, `Quantum`, via `:telemetry`,
will emit a "stop" event, with a measurement of how long it
took to execute the job:

```elixir
:telemetry.execute([:quantum, :job, :start], %{system_time: system_time}, %{
  job: job,
  node: node,
  scheduler: scheduler
})
```

### Quantum Telemetry Events

The following events are published by Quantum with the following measurements and metadata:

* `[:quantum, :job, :start]` - dispatched on job execution start
  * Measurement: `%{system_time: system_time}`
  * Metadata: `%{job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}`
* `[:quantum, :job, :exception]` - dispatched on job execution fail
  * Measurement: `%{duration: native_time}`
  * Metadata: `%{job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), reason: term(), stacktrace: __STACKTRACE__}`
* `[:quantum, :job, :stop]` - dispatched on job execution end
  * Measurement: `%{duration: native_time}`
  * Metadata: `%{job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}`
* `[:quantum, :job, :add]` - dispatched when a job is added
  * Measurement: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`
* `[:quantum, :job, :update]` - dispatched when a job is updated
  * Measurement: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`
* `[:quantum, :job, :delete]` - dispatched when a job is deleted
  * Measurement: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`
