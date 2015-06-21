defmodule Quantum.Normalizer do

  @moduledoc false

  # Converts a job {expr, fun} into its canonical format.
  # Cron expression is converted to lowercase string and
  # day and month names are translated to their indexes.
  def normalize({e, fun}), do: {do_normalize(e), fun}
  
  defp do_normalize(e) when e |> is_atom, do: do_normalize e |> Atom.to_string
  defp do_normalize(e), do: e |> String.downcase |> Quantum.Translator.translate

end
