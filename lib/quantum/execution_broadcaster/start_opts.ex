defmodule Quantum.ExecutionBroadcaster.StartOpts do
  @moduledoc false

  # Start Options for Quantum.ExecutionBroadcaster

  alias Quantum.{Scheduler, Storage.Adapter}

  @type t :: %__MODULE__{
          name: GenServer.server(),
          job_broadcaster_reference: GenServer.server(),
          storage: Adapter,
          scheduler: Scheduler,
          debug_logging: boolean
        }

  @enforce_keys [:name, :job_broadcaster_reference, :storage, :scheduler, :debug_logging]
  defstruct @enforce_keys
end
