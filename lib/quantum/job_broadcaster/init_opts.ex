defmodule Quantum.JobBroadcaster.InitOpts do
  @moduledoc false

  # Init Options for Quantum.JobBroadcaster

  alias Quantum.{Job, Scheduler, Storage.Adapter}

  @type t :: %__MODULE__{
          jobs: [Job.t()],
          storage: Adapter,
          scheduler: Scheduler,
          debug_logging: boolean
        }

  @enforce_keys [:jobs, :storage, :scheduler, :debug_logging]
  defstruct @enforce_keys
end
