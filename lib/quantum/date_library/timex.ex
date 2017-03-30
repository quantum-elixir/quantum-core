if Code.ensure_compiled?(Timex) do
  defmodule Quantum.DateLibrary.Timex do
    @moduledoc false

    @behaviour Quantum.DateLibrary

    def utc_to_tz(date, tz) do
      date
      |> DateTime.from_naive!("Etc/UTC")
      |> Timex.Timezone.convert(tz)
      |> DateTime.to_naive
    end
  end
end
