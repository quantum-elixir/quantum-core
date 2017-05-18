defmodule Quantum.Config do
  @moduledoc false

  require Logger

  def get do
    check_for_old_configuration()

    List.flatten [
      Application.get_all_env(:quantum)
      |> Keyword.values
      |> Enum.filter(&is_list(&1))
      |> Enum.map(&Keyword.get(&1, :cron, []))
      |> List.flatten,

      Application.get_env(:quantum, :cron, [])
    ]
  end

  defp check_for_old_configuration do
    crons = Application.get_env(:quantum, :cron, false)
    if crons do
      Logger.warn ~s"""
        Configuring the cron configuration is deprecated. Please use the new syntax instead.

        Example:
        #{pretty_print_cron_config(crons)}
        """
    end
  end

  defp pretty_print_cron_config(crons) do
    crons = crons
    |> inspect(pretty: true)
    |> String.split("\n")
    |> Enum.map(&"          " <> &1)
    |> Enum.join("\n")
    |> String.trim

    ~s"""
    config :quantum, :your_app_name, cron: #{crons}
    """
  end
end
