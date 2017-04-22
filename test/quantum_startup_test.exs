defmodule QuantumStartupTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  import Crontab.CronExpression

  @tag :startup
  test "prevent duplicate job names on startup" do
    capture_log(fn ->
      defmodule Scheduler do
        use Quantum.Scheduler, otp_app: :quantum_startup_test
      end

      test_jobs =
        [{:test_job, [schedule: ~e[1 * * * *], task: fn -> :ok end]},
         {:test_job, [schedule: ~e[2 * * * *], task: fn -> :ok end]},
         {"3 * * * *", fn -> :ok end},
         {"4 * * * *", fn -> :ok end}]

      Application.put_env(:quantum_startup_test, QuantumStartupTest.Scheduler, jobs: test_jobs)

      {:ok, _pid} = QuantumStartupTest.Scheduler.start_link()

      assert Enum.count(QuantumStartupTest.Scheduler.jobs) == 3
      assert QuantumStartupTest.Scheduler.find_job(:test_job).schedule == ~e[1 * * * *]
    end)
  end

end
