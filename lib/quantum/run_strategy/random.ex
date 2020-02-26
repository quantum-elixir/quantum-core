defmodule Quantum.RunStrategy.Random do
  @moduledoc """
  Run job on one node of the list randomly.

  If the node list is `:cluster`, one node of the cluster will be used.

  This run strategy also makes sure, that the node doesn't run in two places at the same time
  if `job.overlap` is falsy.

  ### Mix Configuration

      config :my_app, MyApp.Scheduler,
        jobs: [
          # Run on any node in cluster
          [schedule: "* * * * *", run_strategy: {Quantum.RunStrategy.Random, :cluster}],
          # Run on any node of given list
          [schedule: "* * * * *", run_strategy: {Quantum.RunStrategy.Random, [:"node@host1", :"node@host2"]}],
        ]

  """

  @typedoc false
  @type t :: %__MODULE__{nodes: [Node.t()] | :cluster}

  defstruct nodes: nil

  @behaviour Quantum.RunStrategy

  alias Quantum.Job

  @impl Quantum.RunStrategy
  @spec normalize_config!([Node.t()] | :cluster) :: t
  def normalize_config!(nodes) when is_list(nodes) do
    %__MODULE__{nodes: Enum.map(nodes, &normalize_node/1)}
  end

  def normalize_config!(:cluster), do: %__MODULE__{nodes: :cluster}

  @spec normalize_node(Node.t() | binary) :: Node.t()
  defp normalize_node(node) when is_atom(node), do: node
  defp normalize_node(node) when is_binary(node), do: String.to_atom(node)

  defimpl Quantum.RunStrategy.NodeList do
    @spec nodes(Quantum.RunStrategy.Random.t(), Job.t()) :: [Node.t()]
    def nodes(%Quantum.RunStrategy.Random{nodes: :cluster}, _job) do
      [Enum.random([node() | Node.list()])]
    end

    def nodes(%Quantum.RunStrategy.Random{nodes: nodes}, _job) do
      [Enum.random(nodes)]
    end
  end
end
