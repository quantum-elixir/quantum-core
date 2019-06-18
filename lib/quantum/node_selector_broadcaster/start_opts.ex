defmodule Quantum.NodeSelectorBroadcaster.StartOpts do
  @moduledoc false

  # Start Options for Quantum.NodeSelectorBroadcaster

  @type t :: %__MODULE__{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }

  @enforce_keys [
    :name,
    :execution_broadcaster_reference,
    :task_supervisor_reference
  ]
  defstruct @enforce_keys
end
