defmodule Quantum.DateLibrary do
  @moduledoc """
  This Behaviour offers Date Library Independant integration of helper
  functions.

  **This behaviour is considered internal. Breaking Changes can occur on every
  release.**

  Make sure your implementation passes `Quantum.DateLibraryTest`. Otherwise
  unexpected behaviour can occur.
  """

  @callback utc_to_tz(NaiveDateTime.t, String.t) :: NaiveDateTime.t
end
