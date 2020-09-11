defmodule Quantum.ExecutorSupervisor.StartOpts do
  @moduledoc false

  # Start Options for Quantum.ExecutorSupervisor

  @type t :: %__MODULE__{
          name: GenServer.server(),
          node_selector_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server(),
          task_registry_reference: GenServer.server(),
          debug_logging: boolean(),
          scheduler: atom()
        }

  @enforce_keys [
    :name,
    :node_selector_broadcaster_reference,
    :task_supervisor_reference,
    :task_registry_reference,
    :debug_logging,
    :scheduler
  ]
  defstruct @enforce_keys
end
