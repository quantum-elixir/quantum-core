defmodule Quantum.Matcher do

  @moduledoc false

  alias Quantum.Parser

  def match("*", _, _) do
    true
  end

  def match(e, v, range) do
    e |> String.split(",") |> do_match(v, range)
  end

  defp do_match([], _, _) do
    false
  end

  defp do_match([e|t], v, range) do
    Enum.any?(Parser.parse(e, range), &(&1 == v)) or do_match(t, v, range)
  end

end
