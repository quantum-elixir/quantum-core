defmodule Quantum.Parser do

  @moduledoc false

  def parse("*/" <> i, range) do
    range |> only_multiplier_of(i)
  end

  def parse(e, range) do
    [r|i] = e |> String.split("/")
    [x|y] = r |> String.split("-")
    x
    |> String.to_integer
    |> do_parse(y, i, range)
    |> Enum.filter(&(&1 in range))
  end

  defp do_parse(v, [], [], _), do: [v]

  defp do_parse(v, [], [i], _) do
    [rem(v, i |> String.to_integer)]
  end

  defp do_parse(v, [y], [], a..b) do
    t = y |> String.to_integer
    if v < t do
      Enum.to_list(v..t)
    else
      Enum.to_list(a..t) ++ Enum.to_list(v..b)
    end
  end

  defp do_parse(v, y, [i], range) do
    v |> do_parse(y, [], range) |> only_multiplier_of(i)
  end

  defp only_multiplier_of(coll, i) do
    x = i |> String.to_integer
    coll |> Enum.filter(&(rem(&1, x) == 0))
  end

end
