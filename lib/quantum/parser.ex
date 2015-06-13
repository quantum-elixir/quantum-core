defmodule Quantum.Parser do

  @moduledoc false

  def parse([], _, _), do: []
  def parse(e, min, max) when e |> is_list do
    [h|t] = e
    (parse(h, min, max) ++ parse(t, min, max)) |> :lists.usort
  end
  def parse("*/" <> _ = e, min, max) do
    [_,i] = e |> String.split("/")
    {x,_} = i |> Integer.parse
    Enum.reject(min..max, &(rem(&1, x) != 0))
  end
  def parse(e, min, max) do
    [r|i] = e |> String.split("/")
    [x|y] = r |> String.split("-")
    {v,_} = x |> Integer.parse
    parse(v, y, i, min, max) |> Enum.reject(&((&1 < min) or (&1 > max)))
  end
  def parse(v, [], [], _, _), do: [v]
  def parse(v, [], [i], _, _) do
    {x,_} = i |> Integer.parse
    [rem(v,x)]
  end
  def parse(v, [y], [], min, max) do
    {t,_} = y |> Integer.parse
    if v < t do
      Enum.to_list(v..t)
    else
      Enum.to_list(min..t) ++ Enum.to_list(v..max)
    end
  end
  def parse(v, y, [i], min, max) do
    {x,_} = i |> Integer.parse
    parse(v, y, [], min, max) |> Enum.reject(&(rem(&1, x) != 0))
  end

end
