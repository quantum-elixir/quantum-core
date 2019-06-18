defmodule Quantum.NodeSelectorBroadcaster.InitOpts do
  @moduledoc false

  # Init Options for Quantum.NodeSelectorBroadcaster

  @type t :: %__MODULE__{
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }

  @enforce_keys [
    :execution_broadcaster_reference,
    :task_supervisor_reference
  ]
  defstruct @enforce_keys
end
