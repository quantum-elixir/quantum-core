defmodule QuantumStartupTest do
  use ExUnit.Case

  @tag :startup
  test "prevent duplicate job names on startup" do
    test_jobs =
      [test_job: [schedule: "1 * * * *", task: fn -> :ok end],
       test_job: [schedule: "2 * * * *", task: fn -> :ok end],
       "3 * * * *": fn -> :ok end,
       "4 * * * *": fn -> :ok end]

    Application.stop(:quantum)
    Application.put_env(:quantum, :cron, test_jobs)
    Application.ensure_started(:logger)
    Application.ensure_all_started(:quantum)
    
    assert Enum.count(Quantum.jobs) == 3
    assert Quantum.find_job(:test_job).schedule == "1 * * * *"
  end

end
