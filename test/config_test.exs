defmodule Quantum.ConfigTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Quantum.Config

  setup do
    # Clear Env
    Application.get_all_env(:quantum)
    |> Enum.each(fn {key, _value} -> Application.delete_env(:quantum, key) end)
  end

  test "get/0 extracts all configuration for all applications" do
    capture_log(fn ->
      Application.put_env(:quantum, :some_app1, [cron: [1, 2, 3]])
      Application.put_env(:quantum, :some_app2, [cron: [4, 5, 6]])
      Application.put_env(:quantum, :cron, [7, 8, 9])

      assert Enum.sort(Config.get) == Enum.to_list 1..9
    end)
  end

  test "get/0 will show warning if old crons is configured" do
    Application.put_env(:quantum, :cron, [1, 2, 3])

    fun = fn ->
      Config.get
    end

    assert capture_log(fun) =~ ~s"""
      Configuring the cron configuration is deprecated. Please use the new syntax instead.

      Example:
      config :quantum, :your_app_name, cron: [1, 2, 3]
      """
  end
end
