defmodule Quantum.ExecutionBroadcaster.State do
  @moduledoc false

  # Internal State

  alias Quantum.Job
  alias Quantum.Storage, as: StorageAdapter

  @type t :: %__MODULE__{
          uninitialized_jobs: [Job.t()],
          execution_timeline: [{NaiveDateTime.t(), [Job.t()]}],
          storage: StorageAdapter,
          storage_pid: StorageAdapter.storage_pid(),
          scheduler: Quantum,
          debug_logging: boolean()
        }

  @enforce_keys [
    :uninitialized_jobs,
    :execution_timeline,
    :storage,
    :storage_pid,
    :scheduler,
    :debug_logging
  ]

  defstruct @enforce_keys
end
