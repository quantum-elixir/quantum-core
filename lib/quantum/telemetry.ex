defmodule Quantum.Telemetry do
  use TelemetryRegistry

  telemetry_event(%{
    event: [:quantum, :job, :add],
    description: "dispatched when a job is added",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :update],
    description: "dispatched when a job is updated",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :delete],
    description: "dispatched when a job is deleted",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :start],
    description: "dispatched on job execution start",
    measurements: "%{system_time: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :stop],
    description: "dispatched on job execution end",
    measurements: "%{duration: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :exception],
    description: "dispatched on job execution fail",
    measurements: "%{duration: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}"
  })

  @moduledoc """
  This is a module detailing the telemetry events emitted by this library

  ## Telemetry

  #{telemetry_docs()}

  ## Examples

      iex(1)> :telemetry_registry.discover_all(:quantum)
      :ok
      iex(2)> :telemetry_registry.spannable_events()
      [{[:quantum, :job], [:start, :stop, :exception]}]
      iex(3)> :telemetry_registry.list_events
      [
        {[:quantum, :job, :add], Quantum.Telemetry,
         %{
           description: "dispatched when a job is added",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :delete], Quantum.Telemetry,
         %{
           description: "dispatched when a job is deleted",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :exception], Quantum.Telemetry,
         %{
           description: "dispatched on job execution fail",
           measurements: "%{duration: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}"
         }},
        {[:quantum, :job, :start], Quantum.Telemetry,
         %{
           description: "dispatched on job execution start",
           measurements: "%{system_time: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :stop], Quantum.Telemetry,
         %{
           description: "dispatched on job execution end",
           measurements: "%{duration: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}"
         }},
        {[:quantum, :job, :update], Quantum.Telemetry,
         %{
           description: "dispatched when a job is updated",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }}
      ]
  """
end
