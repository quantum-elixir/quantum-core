defmodule Quantum.RunStrategy do
  @moduledoc """
  Config Normalizer of a `Quantum.RunStrategy.NodeList`.
  """

  @doc """
  Normalize given config to a value that has `Quantum.RunStrategy.NodeList` implemented.

  Raise / Do not Match on invalid config.
  """
  @callback normalize_config!(any) :: any

  defprotocol NodeList do
    @moduledoc """
    Strategy to run Jobs over nodes
    """

    @doc """
    Get nodes to run on
    """
    @spec nodes(any, Quantum.Job.t()) :: [Node.t()]
    def nodes(strategy, job)
  end
end
