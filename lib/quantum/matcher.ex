defmodule Quantum.Matcher do

  @moduledoc false

  alias Quantum.Parser

  def match("*", _, _, _) do
    true
  end

  def match(e, v, a, b) do
    do_match(e |> String.split(","), v, a, b)
  end

  defp do_match([], _, _, _) do
    false
  end

  defp do_match([e|t], v, a, b) do
    Enum.any?(Parser.parse(e, a, b), &(&1 == v)) or do_match(t, v, a, b)
  end

end
