defmodule Quantum.NormalizerTest do
  use ExUnit.Case

  import Quantum.Normalizer
  import Crontab.CronExpression

  alias Quantum.Job

  defmodule Runner do
    use Quantum, otp_app: :quantum_test
  end

  defp start_runner(name) do
    {:ok, _pid} = name.start_link()
    on_exit fn ->
      case Process.whereis(Quantum.Supervisor) do
        nil ->
          :ok
        pid ->
          name.stop(pid)
      end
    end
  end

  setup do
    Application.put_env(:quantum_test, Quantum.NormalizerTest.Runner, jobs: [])

    start_runner(Quantum.NormalizerTest.Runner)
  end

  test "named job" do
    job = {:newsletter, [
      schedule: ~e[@weekly],
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
      nodes: [:atom@node, "string@node"]
    ]}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[@weekly])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)
    |> Job.set_nodes([:atom@node, :string@node])

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

  test "expression tuple extended" do
    job = {:newsletter, [
      schedule: {:extended, "*"},
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
      nodes: [:atom@node, "string@node"]
    ]}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[*]e)
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)
    |> Job.set_nodes([:atom@node, :string@node])

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

  test "expression tuple not extended" do
    job = {:newsletter, [
      schedule: {:cron, "*"},
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
      nodes: [:atom@node, "string@node"]
    ]}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[*])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)
    |> Job.set_nodes([:atom@node, :string@node])

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

  test "named job with old schedule" do
    job = {:newsletter, [
      schedule: "@weekly",
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
      nodes: [:atom@node, "string@node"]
    ]}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[@weekly])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)
    |> Job.set_nodes([:atom@node, :string@node])

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

  test "unnamed job as tuple" do
    job = {~e[* * * * *], {MyModule, :my_method, [1, 2, 3]}}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

  test "unnamed job as tuple with arguments" do
    job = {"* * * * *", {MyModule, :my_method, [1, 2, 3]}}

    expected_job = Quantum.NormalizerTest.Runner.new_job()
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})

    assert normalize(Quantum.NormalizerTest.Runner.new_job(), job) == expected_job
  end

end
