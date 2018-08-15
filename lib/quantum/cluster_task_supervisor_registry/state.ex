defmodule Quantum.ClusterTaskSupervisorRegistry.State do
  @moduledoc false

  # State of Quantum.ClusterTaskSupervisorRegistry

  @type t :: %__MODULE__{
          group_name: atom(),
          task_supervisor_pid: GenServer.server(),
          monitor_ref: reference
        }

  @enforce_keys [:group_name, :task_supervisor_pid, :monitor_ref]
  defstruct @enforce_keys
end
