defmodule Quantum.DateLibrary do
  @moduledoc """
  This Behaviour offers Date Library Independant integration of helper
  functions.

  **This behaviour is considered internal. Breaking Changes can occur on every
  release.**

  Make sure your implementation passes `Quantum.DateLibraryTest`. Otherwise
  unexpected behaviour can occur.
  """

  @date_library Application.get_env(:quantum, :date_library, Quantum.DateLibrary.Timex)

  @doc """
  Convert `NaiveDateTime` in UTC to `NaiveDateTime` in given tz.
  """
  @callback utc_to_tz!(NaiveDateTime.t, String.t) :: NaiveDateTime.t | no_return

  @doc """
  Convert `NaiveDateTime` in given tz to `NaiveDateTime` in UTC.
  """
  @callback tz_to_utc!(NaiveDateTime.t, String.t) :: NaiveDateTime.t | no_return

  @doc """
  Gives back the required application dependency to start, if any is needed.
  """
  @callback dependency_application :: atom | nil

  @doc """
  Convert Date to Utc
  """
  @spec to_utc!(NaiveDateTime.t, :utc | binary) :: NaiveDateTime.t | no_return
  def to_utc!(date, :utc), do: date
  def to_utc!(date, tz) when is_binary(tz), do: @date_library.tz_to_utc!(date, tz)

  @doc """
  Convert Date to TZ
  """
  @spec to_utc!(NaiveDateTime.t, :utc | binary) :: NaiveDateTime.t | no_return
  def to_tz!(date, :utc), do: date
  def to_tz!(date, tz) when is_binary(tz), do: @date_library.utc_to_tz!(date, tz)
end
