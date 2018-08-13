defmodule Quantum.ExecutionBroadcaster.Event do
  @moduledoc false

  # Execute Event

  alias Quantum.Job

  @type t :: %__MODULE__{
          job: Job.t()
        }

  @enforce_keys [:job]

  defstruct @enforce_keys
end
