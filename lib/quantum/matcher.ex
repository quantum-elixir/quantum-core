defmodule Quantum.Matcher do

  @moduledoc false

  def match("*", _, _, _) do
    true
  end

  def match(e, v, min, max) do
    do_match(e |> String.split(","), v, min, max)
  end

  defp do_match([], _, _, _) do
    false
  end

  defp do_match([e|t], v, min, max) do
    Enum.any?(Quantum.Parser.parse(e, min, max), &(&1 == v)) or do_match(t, v, min, max)
  end

end
