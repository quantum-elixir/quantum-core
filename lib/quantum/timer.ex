defmodule Quantum.Timer do
  @moduledoc false

  def timezone_function do
    case Application.get_env(:quantum, :timezone, :utc) do
      :utc ->
        &:calendar.now_to_universal_time/1
      :local ->
        &:calendar.now_to_local_time/1
      timezone ->
        &custom(timezone, &1)
    end
  end

  def tick do
    {_, _, ms_raw} = :os.timestamp()
    ms = 1000 - :erlang.round(ms_raw / 1000)
    Process.send_after(self(), :tick, ms)
    {d, {h, m, s}} = timezone_function().(:os.timestamp)
    {d, h, m, s}
  end

  def custom(timezone, _) do
    timezone
    |> Calendar.DateTime.now!
    |> Calendar.DateTime.to_erl
  end
end
