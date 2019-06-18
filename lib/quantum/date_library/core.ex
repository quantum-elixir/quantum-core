if Version.match?(System.version(), ">= 1.8.0") do
  defmodule Quantum.DateLibrary.Core do
    @moduledoc """
    Elixir core implementation of `Quantum.DateLibrary`.

    **This behaviour is considered internal. Breaking Changes can occur on every
    release.**

    ### Installation
      `config.exs`

        config :quantum,
          date_library: Quantum.DateLibrary.Core

      `mix.exs`

        defp deps do
          [{:quantum, "*"}]
        end
    """

    @behaviour Quantum.DateLibrary

    require Logger

    alias Quantum.DateLibrary.{InvalidDateTimeForTimezoneError, InvalidTimezoneError}

    @spec utc_to_tz!(NaiveDateTime.t(), String.t()) :: NaiveDateTime.t() | no_return
    def utc_to_tz!(date, tz) do
      result =
        date
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.shift_zone(tz)

      case result do
        {:ok, dt} ->
          DateTime.to_naive(dt)

        {:error, :time_zone_not_found} ->
          raise InvalidTimezoneError

        {:error, :utc_only_time_zone_database} ->
          Logger.warn("Timezone database not setup")
          raise InvalidTimezoneError
      end
    end

    @spec tz_to_utc!(NaiveDateTime.t(), String.t()) :: NaiveDateTime.t() | no_return
    def tz_to_utc!(date, tz) do
      dt =
        case DateTime.from_naive(date, tz) do
          {:ok, dt} ->
            dt

          {:ambiguous, _, _} ->
            raise InvalidDateTimeForTimezoneError

          {:gap, _, _} ->
            raise InvalidDateTimeForTimezoneError

          {:error, :incompatible_calendars} ->
            raise InvalidDateTimeForTimezoneError

          {:error, :time_zone_not_found} ->
            raise InvalidTimezoneError

          {:error, :utc_only_time_zone_database} ->
            Logger.warn("Timezone database not setup")
            raise InvalidTimezoneError
        end

      case DateTime.shift_zone(dt, "Etc/UTC") do
        {:ok, dt} ->
          DateTime.to_naive(dt)

        {:error, :utc_only_time_zone_database} ->
          Logger.warn("Timezone database not setup")
          raise InvalidTimezoneError
      end
    end

    @spec dependency_application :: nil
    def dependency_application, do: nil
  end
end
