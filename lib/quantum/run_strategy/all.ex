defmodule Quantum.RunStrategy.All do
  @moduledoc """
  Run job on all node of the node list

  If the node list is `:cluster`, all nodes of the cluster will be used.

  ### Mix Configuration

      config :my_app, MyApp.Scheduler,
        jobs: [
          # Run on all nodes in cluster
          [schedule: "* * * * *", run_strategy: {Quantum.RunStrategy.All, :cluster}],
          # Run on all nodes of given list
          [schedule: "* * * * *", run_strategy: {Quantum.RunStrategy.All, [:"node@host1", :"node@host2"]}],
        ]
      ```
      
  """

  @type t :: %__MODULE__{nodes: [Node.t | :cluster]}

  defstruct [nodes: nil]

  @behaviour Quantum.RunStrategy

  def normalize_config!(nodes) when is_list(nodes) do
    %__MODULE__{nodes: Enum.map(nodes, &normalize_node/1)}
  end
  def normalize_config!(:cluster), do: %__MODULE__{nodes: :cluster}

  defp normalize_node(node) when is_atom(node), do: node
  defp normalize_node(node) when is_binary(node), do: String.to_atom(node)

  defimpl Quantum.RunStrategy.NodeList do
    def nodes(%Quantum.RunStrategy.All{nodes: :cluster}, _) do
      [node() | Node.list]
    end
    def nodes(%Quantum.RunStrategy.All{nodes: nodes}, _) do
      nodes
    end
  end
end
