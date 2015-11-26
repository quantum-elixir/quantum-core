defmodule Quantum.Timer do

  @moduledoc false

  now = case Application.get_env(:quantum, :timezone, :utc) do
    :utc ->
      &:calendar.now_to_universal_time/1
    :local ->
      &:calendar.now_to_local_time/1
    timezone ->
      raise "Unsupported timezone: #{timezone}"
  end

  def tick do
    {d, {h, m, s}} = unquote(now).(:os.timestamp)
    Process.send_after(self, :tick, (60 - s) * 1000)
    {d, h, m}
  end

end
