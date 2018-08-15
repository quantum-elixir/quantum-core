defmodule Quantum.TaskRegistry.State do
  @moduledoc false

  # State of Quantum.TaskRegistry

  alias Quantum.Job

  @type t :: %__MODULE__{
          running_tasks: %{optional(Job.name()) => [Node.t()]}
        }

  @enforce_keys [:running_tasks]
  defstruct @enforce_keys
end
