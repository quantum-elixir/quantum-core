defmodule Quantum.RunStrategyTest do
  use ExUnit.Case, async: true

  alias Quantum.Job
  alias Quantum.RunStrategy.NodeList

  defmodule Scheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :quantum_test
  end

  test "run strategy local" do
    job = Scheduler.config(run_strategy: Quantum.RunStrategy.Local) |> Job.new()
    assert %Job{} = job
    assert [_] = NodeList.nodes(job.run_strategy, job)
  end

  test "run strategy random" do
    job =
      Scheduler.config(run_strategy: {Quantum.RunStrategy.Random, [:node1, :node2]}) |> Job.new()

    assert [node] = NodeList.nodes(job.run_strategy, job)
    assert Enum.member?([:node1, :node2], node)
  end

  test "run strategy all" do
    job = Scheduler.config(run_strategy: {Quantum.RunStrategy.All, [:node1, :node2]}) |> Job.new()
    assert [_, _] = NodeList.nodes(job.run_strategy, job)
  end
end
