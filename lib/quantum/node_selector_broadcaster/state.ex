defmodule Quantum.NodeSelectorBroadcaster.State do
  @moduledoc false

  # Internal State

  @type t :: %__MODULE__{
          task_supervisor_reference: GenServer.server()
        }

  @enforce_keys [
    :task_supervisor_reference
  ]

  defstruct @enforce_keys
end
