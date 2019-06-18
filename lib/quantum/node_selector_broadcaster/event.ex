defmodule Quantum.NodeSelectorBroadcaster.Event do
  @moduledoc false

  # Execute Event

  alias Quantum.Job

  @type t :: %__MODULE__{
          job: Job.t(),
          node: Node.t()
        }

  @enforce_keys [:job, :node]

  defstruct @enforce_keys
end
