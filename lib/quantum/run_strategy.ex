defprotocol Quantum.RunStrategy do
  @moduledoc """
  Strategy to run Jobs over nodes
  """

  @doc """
  Get nodes to run on
  """
  def nodes(strategy, job)
end
