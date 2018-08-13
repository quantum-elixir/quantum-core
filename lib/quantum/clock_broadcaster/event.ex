defmodule Quantum.ClockBroadcaster.Event do
  @moduledoc false

  # Clock Event

  @type t :: %__MODULE__{
          time: NaiveDateTime.t(),
          catch_up: boolean()
        }

  @enforce_keys [:time, :catch_up]

  defstruct @enforce_keys
end
