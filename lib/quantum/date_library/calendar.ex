if Code.ensure_compiled?(Calendar) do
  defmodule Quantum.DateLibrary.Calendar do
    @moduledoc false

    @behaviour Quantum.DateLibrary

    def utc_to_tz(date, tz) do
      date
      |> DateTime.from_naive!("Etc/UTC")
      |> Calendar.DateTime.shift_zone!(tz)
      |> DateTime.to_naive
    end
  end
end
