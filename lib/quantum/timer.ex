defmodule Quantum.Timer do
  @moduledoc false

  @doc """
  Send a tick as soon as the next second completes and return the
  current date (beginning of the second)
  
  """
  @spec tick() :: NaiveDateTime.t
  def tick do
    {_, _, ms_raw} = :os.timestamp()
    ms = 1000 - :erlang.round(ms_raw / 1000)
    Process.send_after(self(), :tick, ms)

    NaiveDateTime.utc_now
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
  end
end
