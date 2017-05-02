defmodule Quantum.RunStrategy.Random do
  @moduledoc """
  Run job on one node of the list randomly.

  If the node list is `:cluster`, one node of the cluster will be used.

  This run strategy also makes sure, that the node doesn't run in two places at the same time
  if `job.overlap` is falsy.
  """

  @type t :: %__MODULE__{nodes: [Node.t] | :cluster}

  defstruct [nodes: nil]

  defimpl Quantum.RunStrategy do
    alias Quantum.Job

    def nodes(%Quantum.RunStrategy.Random{nodes: :cluster}, job) do
      if job_pending?(job) do
        []
      else
        [node() | Node.list]
        |> Enum.shuffle
        |> Enum.take(1)
      end
    end
    def nodes(%Quantum.RunStrategy.Random{nodes: nodes}, job) do
      if job_pending?(job) do
        []
      else
        nodes
        |> Enum.shuffle
        |> Enum.take(1)
      end
    end

    defp job_pending?(%Job{overlap: false, pids: pids}) do
      count = pids
      |> Enum.reject(fn({_, pid}) -> pid == nil end)
      |> Enum.filter(fn({_, pid}) -> Job.is_alive?(pid) end)
      |> Enum.count
      count > 0
    end
    defp job_pending?(%Job{overlap: true}) do
      false
    end
  end
end
