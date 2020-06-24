defmodule Quantum.DateLibrary do
  @moduledoc false

  require Logger

  alias Quantum.DateLibrary.{InvalidDateTimeForTimezoneError, InvalidTimezoneError}

  # Convert Date to Utc
  @spec to_utc!(NaiveDateTime.t(), :utc | String.t()) :: NaiveDateTime.t()

  def to_utc!(date, :utc), do: date

  def to_utc!(date, tz) when is_binary(tz) do
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
          Logger.warn("Timezone database not set up")
          raise InvalidTimezoneError
      end

    case DateTime.shift_zone(dt, "Etc/UTC") do
      {:ok, dt} ->
        DateTime.to_naive(dt)

      {:error, :utc_only_time_zone_database} ->
        Logger.warn("Timezone database not set up")
        raise InvalidTimezoneError
    end
  end

  # Convert Date to TZ
  @spec to_tz!(NaiveDateTime.t(), :utc | String.t()) :: NaiveDateTime.t()
  def to_tz!(date, :utc), do: date

  def to_tz!(date, tz) when is_binary(tz) do
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
        Logger.warn("Timezone database not set up")
        raise InvalidTimezoneError
    end
  end

  defmodule InvalidDateTimeForTimezoneError do
    @moduledoc false

    defexception message: "The requested time does not exist in the given timezone."
  end

  defmodule InvalidTimezoneError do
    @moduledoc false

    defexception message: "The requested timezone is invalid."
  end
end
