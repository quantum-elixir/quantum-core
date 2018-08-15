defmodule Quantum.ClusterTaskSupervisorRegistry.StartOpts do
  @moduledoc false

  # Start Options for Quantum.ClusterTaskSupervisorRegistry

  @type t :: %__MODULE__{
          name: GenServer.server(),
          task_supervisor_reference: GenServer.server(),
          group_name: atom() | nil
        }

  @enforce_keys [:name, :task_supervisor_reference]
  defstruct @enforce_keys ++ [:group_name]
end
