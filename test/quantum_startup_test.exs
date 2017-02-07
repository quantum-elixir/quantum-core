defmodule QuantumStartupTest do
  use ExUnit.Case

  import Crontab.CronExpression

  setup do
    # Clear Env
    Application.get_all_env(:quantum)
    |> Enum.each(fn {key, _value} -> Application.delete_env(:quantum, key) end)
  end

  @tag :startup
  test "prevent duplicate job names on startup" do
    test_jobs =
      [test_job: [schedule: ~e[1 * * * *], task: fn -> :ok end],
       test_job: [schedule: ~e[2 * * * *], task: fn -> :ok end],
       "3 * * * *": fn -> :ok end,
       "4 * * * *": fn -> :ok end]

    Application.stop(:quantum)
    Application.put_env(:quantum, :some_app, cron: test_jobs)
    Application.ensure_started(:logger)
    Application.ensure_all_started(:quantum)
    
    assert Enum.count(Quantum.jobs) == 3
    assert Quantum.find_job(:test_job).schedule == ~e[1 * * * *]
  end

end
