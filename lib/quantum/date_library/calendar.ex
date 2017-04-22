if Code.ensure_compiled?(Calendar) do
  defmodule Quantum.DateLibrary.Calendar do
    @moduledoc """
    `calendar` implementation of `Quantum.DateLibrary`.

    **This behaviour is considered internal. Breaking Changes can occur on every
    release.**

    ### Installation
      `config.exs`

        config :quantum,
          date_library: Quantum.DateLibrary.Calendar

      `mix.exs`

        def application do
          [applications: [:quantum, :calendar]]
        end

        defp deps do
          [{:quantum, "*"},
           {:calendar, "*"}]
        end
    """

    @behaviour Quantum.DateLibrary

    @spec utc_to_tz(NaiveDateTime.t, String.t) :: NaiveDateTime.t | no_return
    def utc_to_tz(date, tz) do
      date
      |> DateTime.from_naive!("Etc/UTC")
      |> Calendar.DateTime.shift_zone!(tz)
      |> DateTime.to_naive
    end
  end
end
