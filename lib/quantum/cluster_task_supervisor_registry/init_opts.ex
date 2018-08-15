defmodule Quantum.ClusterTaskSupervisorRegistry.InitOpts do
  @moduledoc false

  # Init Options for Quantum.ClusterTaskSupervisorRegistry

  @type t :: %__MODULE__{
          task_supervisor_reference: GenServer.server(),
          group_name: atom()
        }

  @enforce_keys [:task_supervisor_reference, :group_name]
  defstruct @enforce_keys
end
