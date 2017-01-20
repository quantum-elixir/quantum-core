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
    miliseconds = 1000 - (:os.system_time(:millisecond) - :os.system_time(:seconds) * 1000)
    Process.send_after(self(), :tick, miliseconds)
    {d, {h, m, s}} = timezone_function().(:os.timestamp)
    {d, h, m, s}
  end

  def custom(timezone, _) do
    Calendar.DateTime.now!(timezone) |> Calendar.DateTime.to_erl
  end
end
