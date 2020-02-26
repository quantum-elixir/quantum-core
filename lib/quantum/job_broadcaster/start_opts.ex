defmodule Quantum.JobBroadcaster.StartOpts do
  @moduledoc false

  # Start Options for Quantum.JobBroadcaster

  alias Quantum.{Job, Scheduler, Storage}

  @type t :: %__MODULE__{
          name: GenServer.server(),
          jobs: [Job.t()],
          storage: Storage,
          scheduler: Scheduler,
          debug_logging: boolean
        }

  @enforce_keys [:name, :jobs, :storage, :scheduler, :debug_logging]
  defstruct @enforce_keys
end
