defmodule Quantum.ClockBroadcaster.State do
  @moduledoc false

  # Internal State

  @type t :: %__MODULE__{
          debug_logging: boolean(),
          time: NaiveDateTime.t(),
          remaining_demand: non_neg_integer
        }

  @enforce_keys [:debug_logging, :time, :remaining_demand]

  defstruct @enforce_keys
end
