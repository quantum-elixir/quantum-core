defmodule Quantum.Executor.StartOpts do
  @moduledoc false

  # Start Options for Quantum.Executor

  @type t :: %__MODULE__{
          task_supervisor_reference: GenServer.server(),
          task_registry_reference: GenServer.server(),
          debug_logging: boolean,
          cluster_task_supervisor_registry_reference: GenServer.server() | nil
        }

  @enforce_keys [
    :task_supervisor_reference,
    :task_registry_reference,
    :debug_logging,
    :cluster_task_supervisor_registry_reference
  ]
  defstruct @enforce_keys
end
