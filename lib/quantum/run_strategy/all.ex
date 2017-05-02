defmodule Quantum.RunStrategy.All do
  @moduledoc """
  Run job on all node of the node list

  If the node list is `:cluster`, all nodes of the cluster will be used.
  """

  @type t :: %__MODULE__{nodes: [Node.t | :cluster]}

  defstruct [nodes: nil]

  defimpl Quantum.RunStrategy do
    def nodes(%Quantum.RunStrategy.All{nodes: :cluster}, _) do
      [node() | Node.list]
    end
    def nodes(%Quantum.RunStrategy.All{nodes: nodes}, _) do
      nodes
    end
  end
end
