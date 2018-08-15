defmodule Quantum.TaskRegistry.StartOpts do
  @moduledoc false

  # Start Options for Quantum.TaskRegistry

  @type t :: %__MODULE__{
          name: GenServer.server()
        }

  @enforce_keys [:name]
  defstruct @enforce_keys
end
