if Code.ensure_compiled?(Timex) do
  defmodule Quantum.DateLibrary.Timex do
    @moduledoc """
    `timex` implementation of `Quantum.DateLibrary`.

    **This behaviour is considered internal. Breaking Changes can occur on every
    release.**

    ### Installation
      `config.exs`

        config :quantum,
          date_library: Quantum.DateLibrary.Timex

      `mix.exs`

        defp deps do
          [{:quantum, "*"},
           {:timex, "*"}]
        end
    """

    @behaviour Quantum.DateLibrary

    alias Timex.Timezone

    @spec utc_to_tz!(NaiveDateTime.t, String.t) :: NaiveDateTime.t | no_return
    def utc_to_tz!(date, tz) do
      date
      |> DateTime.from_naive!("Etc/UTC")
      |> Timezone.convert(tz)
      |> DateTime.to_naive
    end

    @spec tz_to_utc!(NaiveDateTime.t, String.t) :: NaiveDateTime.t | no_return
    def tz_to_utc!(date, tz) do
      date
      |> Timex.to_datetime(tz)
      |> Timezone.convert("Etc/UTC")
      |> DateTime.to_naive
    end

    @spec dependency_application :: :timex
    def dependency_application, do: :timex
  end
end
