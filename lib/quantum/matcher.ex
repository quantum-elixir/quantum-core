defmodule Quantum.Matcher do
  import Quantum.Parser

  @moduledoc false

  def match("*", _, _, _) do
    true
  end

  def match([], _, _, _) do
    false
  end

  def match([e|t], v, min, max) do
    Enum.any?(parse(e, min, max), &(&1 == v)) or match(t, v, min, max)
  end

  def match(e, v, min, max) do
    match(e |> String.split(","), v, min, max)
  end

end