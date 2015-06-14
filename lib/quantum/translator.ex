defmodule Quantum.Translator do

  @moduledoc false

  @days   ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
  @months ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]  

  # Replaces all occurrences of abbreviated day and month names by their index
  def translate(s) do
    {s, _} = List.foldl @days,   {s, 0}, fn n, acc -> do_translate acc, n end
    {s, _} = List.foldl @months, {s, 1}, fn n, acc -> do_translate acc, n end
    s
  end

  defp do_translate({s, i}, n) do
    {String.replace(s, n, "#{i}"), i + 1}
  end

end
