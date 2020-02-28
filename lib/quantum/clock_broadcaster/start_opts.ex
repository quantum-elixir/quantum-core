defmodule Quantum.ClockBroadcaster.StartOpts do
  @moduledoc false

  # Start Options

  alias Quantum.{Scheduler, Storage}

  @type t :: %__MODULE__{
          name: GenServer.server(),
          start_time: NaiveDateTime.t(),
          storage: Storage,
          scheduler: Scheduler,
          debug_logging: boolean()
        }

  @enforce_keys [:start_time, :name, :storage, :scheduler, :debug_logging]

  defstruct @enforce_keys
end
