defmodule Quantum.Timer do
  @moduledoc false

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
