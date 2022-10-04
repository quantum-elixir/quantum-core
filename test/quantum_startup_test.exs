defmodule QuantumStartupTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureLog

  import Crontab.CronExpression

  defmodule Scheduler do
    @moduledoc false

    use Quantum, otp_app: :quantum
  end

  @tag :startup
  test "prevent duplicate job names on startup" do
    capture_log(fn ->
      test_jobs = [
        {:test_job, [schedule: ~e[1 * * * *], task: fn -> :ok end]},
        {:test_job, [schedule: ~e[2 * * * *], task: fn -> :ok end]},
        {:inactive_job, [schedule: ~e[* * * * *], task: fn -> :ok end, state: :inactive]},
        {"3 * * * *", fn -> :ok end},
        {"4 * * * *", fn -> :ok end}
      ]

      Application.put_env(:quantum, QuantumStartupTest.Scheduler, jobs: test_jobs)

      start_supervised!(Scheduler)

      assert Enum.count(QuantumStartupTest.Scheduler.jobs()) == 4
      assert QuantumStartupTest.Scheduler.find_job(:test_job).schedule == ~e[1 * * * *]
      assert QuantumStartupTest.Scheduler.find_job(:inactive_job).state == :inactive

      :ok = stop_supervised(Scheduler)
    end)
  end

  @tag :startup
  test "prevent unexported functions on startup" do
    log =
      capture_log(fn ->
        test_jobs = [
          {:existing_function, [schedule: ~e[2 * * * *], task: {IO, :puts, ["hey"]}]},
          {:another_existing_function, [schedule: ~e[2 * * * *], task: {Kernel, :floor, [5.4]}]},
          {:existing_function, [schedule: ~e[2 * * * *], task: {IO, :puts, ["hey"]}]},
          {:inexistent_function,
           [schedule: ~e[2 * * * *], task: {UndefinedModule, :undefined_function, ["argument"]}]}
        ]

        Application.put_env(:quantum, QuantumStartupTest.Scheduler, jobs: test_jobs)

        start_supervised!(Scheduler)

        assert Enum.count(QuantumStartupTest.Scheduler.jobs()) == 2
        :ok = stop_supervised(Scheduler)
      end)

    assert log =~
             "Job with name 'inexistent_function' of scheduler 'Elixir.QuantumStartupTest.Scheduler' not started: invalid task function"
  end
end
