defmodule Quantum.Executor.StartOpts do
  @moduledoc false

  # Start Options for Quantum.Executor

  @type t :: %__MODULE__{
          task_supervisor_reference: GenServer.server(),
          task_registry_reference: GenServer.server(),
          debug_logging: boolean,
          scheduler: atom()
        }

  @enforce_keys [
    :task_supervisor_reference,
    :task_registry_reference,
    :debug_logging,
    :scheduler
  ]
  defstruct @enforce_keys
end
