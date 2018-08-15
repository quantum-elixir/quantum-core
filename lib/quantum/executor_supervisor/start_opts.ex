defmodule Quantum.ExecutorSupervisor.StartOpts do
  @moduledoc false

  # Start Options for Quantum.ExecutorSupervisor

  @type t :: %__MODULE__{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server(),
          task_registry_reference: GenServer.server(),
          cluster_task_supervisor_registry_reference: GenServer.server() | nil,
          debug_logging: boolean()
        }

  @enforce_keys [
    :name,
    :execution_broadcaster_reference,
    :task_supervisor_reference,
    :task_registry_reference,
    :cluster_task_supervisor_registry_reference,
    :debug_logging
  ]
  defstruct @enforce_keys
end
