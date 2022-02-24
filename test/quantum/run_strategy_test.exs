defmodule Quantum.RunStrategyTest do
  use ExUnit.Case, async: true

  alias Quantum.Job
  alias Quantum.RunStrategy.NodeList

  defmodule Scheduler do
    @moduledoc false

    use Quantum, otp_app: :quantum_test
  end

  test "run strategy local" do
    job = Scheduler.new_job(run_strategy: Quantum.RunStrategy.Local)
    assert %Job{} = job
    assert [Node.self()] == NodeList.nodes(job.run_strategy, job)
  end

  test "run strategy random" do
    node_list = [:node1, :node2]
    job = Scheduler.new_job(run_strategy: {Quantum.RunStrategy.Random, node_list})
    assert [node] = NodeList.nodes(job.run_strategy, job)
    assert Enum.member?(node_list, node)
  end

  test "run strategy all" do
    node_list = [:node1, :node2]

    job = Scheduler.new_job(run_strategy: {Quantum.RunStrategy.All, node_list})
    assert [:node1, :node2] == NodeList.nodes(job.run_strategy, job)
  end
end
