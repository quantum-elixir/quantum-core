defmodule Quantum.Timer do
  @moduledoc false

  def tick do
    {_, _, ms_raw} = :os.timestamp()
    ms = 1000 - :erlang.round(ms_raw / 1000)
    Process.send_after(self(), :tick, ms)

    DateTime.utc_now
    |> DateTime.to_naive
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
  end
end
