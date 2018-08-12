defmodule Quantum.ClockBroadcaster.InitOpts do
  @moduledoc false

  # Init Options

  @type t :: %__MODULE__{
          start_time: NaiveDateTime.t(),
          debug_logging: boolean()
        }

  @enforce_keys [:start_time, :debug_logging]

  defstruct @enforce_keys

  def fields, do: @enforce_keys
end
