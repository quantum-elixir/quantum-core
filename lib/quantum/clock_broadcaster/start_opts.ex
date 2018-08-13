defmodule Quantum.ClockBroadcaster.StartOpts do
  @moduledoc false

  # Start Options

  @type t :: %__MODULE__{
          name: GenServer.server(),
          start_time: NaiveDateTime.t(),
          debug_logging: boolean()
        }

  @enforce_keys [:name, :start_time, :debug_logging]

  defstruct @enforce_keys
end
