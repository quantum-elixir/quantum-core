defmodule Quantum.NormalizerTest do
  use ExUnit.Case, async: true

  import Quantum.Normalizer
  import Crontab.CronExpression

  alias Quantum.Job

  defmodule Scheduler do
    use Quantum.Scheduler, otp_app: :quantum_test
  end

  setup_all do
    Application.put_env(:quantum_test, Scheduler, jobs: [])

    {:ok, _pid} = start_supervised(Scheduler)

    :ok
  end

  test "named job" do
    job = {:newsletter, [
      schedule: ~e[@weekly],
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
    ]}

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[@weekly])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "expression tuple extended" do
    job = {:newsletter, [
      schedule: {:extended, "*"},
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
    ]}

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[*]e)
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "normalizer of run strategy" do
    job = {:newsletter, [
      run_strategy: {Quantum.RunStrategy.All, [:"node@host"]}
    ]}

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_run_strategy(%Quantum.RunStrategy.All{nodes: [:"node@host"]})

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "expression tuple not extended" do
    job = {:newsletter, [
      schedule: {:cron, "*"},
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
    ]}

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[*])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "named job with old schedule" do
    job = {:newsletter, [
      schedule: "@weekly",
      task: {MyModule, :my_method, [1, 2, 3]},
      overlap: false,
    ]}

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[@weekly])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "unnamed job as tuple" do
    schedule = ~e[* * * * *]
    task = {MyModule, :my_method, [1, 2, 3]}

    assert %{schedule: ^schedule, task: ^task, name: name} = normalize(Scheduler.new_job(), {schedule, task})
    assert is_reference(name)
  end

  test "unnamed job as tuple with arguments" do
    schedule = ~e[* * * * *]
    task = {MyModule, :my_method, [1, 2, 3]}

    job = {"* * * * *", task}

    assert %{schedule: ^schedule, task: ^task, name: name} = normalize(Scheduler.new_job(), job)
    assert is_reference(name)
  end

  test "named job as a keyword" do
    job = [name: :newsletter, schedule: "@weekly", task: {MyModule, :my_method, [1, 2, 3]}, overlap: false]

    expected_job = Scheduler.new_job()
    |> Job.set_name(:newsletter)
    |> Job.set_schedule(~e[@weekly])
    |> Job.set_task({MyModule, :my_method, [1, 2, 3]})
    |> Job.set_overlap(false)

    assert normalize(Scheduler.new_job(), job) == expected_job
  end

  test "unnamed job as a keyword" do
    schedule = ~e[@weekly]

    job = [schedule: "@weekly", task: {MyModule, :my_method, [1, 2, 3]}, overlap: false]

    assert %{schedule: ^schedule, task: {MyModule, :my_method, [1, 2, 3]}, overlap: false, name: name}
      = normalize(Scheduler.new_job(), job)
    assert is_reference(name)
  end

end
