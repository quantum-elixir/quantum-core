defmodule Quantum.Parser do

  @moduledoc false

  def parse("*/" <> i, min, max) do
    min..max |> only_multiplier_of(i)
  end

  def parse(e, min, max) do
    [r|i] = e |> String.split("/")
    [x|y] = r |> String.split("-")
    v     = x |> String.to_integer
    do_parse(v, y, i, min, max) |> Enum.filter(&(&1 in min..max))
  end

  defp do_parse(v, [], [], _, _), do: [v]

  defp do_parse(v, [], [i], _, _) do
    [rem(v, i |> String.to_integer)]
  end

  defp do_parse(v, [y], [], min, max) do
    t = y |> String.to_integer
    if v < t do
      Enum.to_list(v..t)
    else
      Enum.to_list(min..t) ++ Enum.to_list(v..max)
    end
  end

  defp do_parse(v, y, [i], min, max) do
    do_parse(v, y, [], min, max) |> only_multiplier_of(i)
  end

  defp only_multiplier_of(coll, i) do
    x = i |> String.to_integer
    coll |> Enum.filter(&(rem(&1, x) == 0))
  end

end
