defmodule Quantum.ClockBroadcaster.InitOpts do
  @moduledoc false

  # Init Options

  alias Quantum.{Scheduler, Storage}

  @type t :: %__MODULE__{
          start_time: NaiveDateTime.t(),
          storage: Storage,
          scheduler: Scheduler,
          debug_logging: boolean()
        }

  @enforce_keys [:start_time, :storage, :scheduler, :debug_logging]

  defstruct @enforce_keys
end
