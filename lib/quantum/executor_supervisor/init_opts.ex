defmodule Quantum.ExecutorSupervisor.InitOpts do
  @moduledoc false

  # Init Options for Quantum.ExecutorSupervisor

  @type t :: %__MODULE__{
          node_selector_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server(),
          task_registry_reference: GenServer.server(),
          debug_logging: boolean,
          scheduler: atom()
        }

  @enforce_keys [
    :node_selector_broadcaster_reference,
    :task_supervisor_reference,
    :task_registry_reference,
    :debug_logging,
    :scheduler
  ]
  defstruct @enforce_keys
end
