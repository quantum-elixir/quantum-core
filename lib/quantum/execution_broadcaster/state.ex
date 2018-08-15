defmodule Quantum.ExecutionBroadcaster.State do
  @moduledoc false

  # State of Quantum.ExecutionBroadcaster

  alias Quantum.{Job, Scheduler, Storage}

  @type t :: %__MODULE__{
          jobs: [{NaiveDateTime.t(), [Job.t()]}],
          time: NaiveDateTime.t(),
          timer: {reference(), NaiveDateTime.t()} | nil,
          storage: Storage,
          scheduler: Scheduler,
          debug_logging: boolean()
        }

  @enforce_keys [:jobs, :time, :timer, :storage, :scheduler, :debug_logging]
  defstruct @enforce_keys
end
