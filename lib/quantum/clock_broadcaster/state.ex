defmodule Quantum.ClockBroadcaster.State do
  @moduledoc false

  # Internal State

  @type t :: %__MODULE__{
          debug_logging: boolean(),
          time: NaiveDateTime.t(),
          # catch_up: boolean(),
          remaining_demand: non_neg_integer,
          timer: reference | nil
        }

  @enforce_keys [:debug_logging, :time, :remaining_demand, :timer]

  defstruct @enforce_keys
end
