if Code.ensure_compiled?(Calendar.DateTime) do
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

        defp deps do
          [{:quantum, "*"},
           {:calendar, "*"}]
        end
    """

    @behaviour Quantum.DateLibrary

    alias Calendar.DateTime, as: CalendarDateTime
    alias Calendar.TimeZoneData
    alias Quantum.DateLibrary.{InvalidDateTimeForTimezoneError, InvalidTimezoneError}

    @spec utc_to_tz!(NaiveDateTime.t(), String.t()) :: NaiveDateTime.t() | no_return
    def utc_to_tz!(date, tz) do
      check_tz(tz)

      date
      |> DateTime.from_naive!("Etc/UTC")
      |> CalendarDateTime.shift_zone!(tz)
      |> DateTime.to_naive()
    end

    @spec tz_to_utc!(NaiveDateTime.t(), String.t()) :: NaiveDateTime.t() | no_return
    def tz_to_utc!(date, tz) do
      check_tz(tz)

      date
      |> CalendarDateTime.from_naive(tz)
      |> case do
        {:ok, tz_date} ->
          tz_date
          |> CalendarDateTime.shift_zone!("Etc/UTC")
          |> DateTime.to_naive()

        {:error, :invalid_datetime_for_timezone} ->
          raise InvalidDateTimeForTimezoneError
      end
    end

    @spec dependency_application :: :calendar
    def dependency_application, do: :calendar

    defp check_tz(tz) do
      unless TimeZoneData.zone_exists?(tz) do
        raise InvalidTimezoneError
      end
    end
  end
end
