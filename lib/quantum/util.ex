defmodule Quantum.Util do
  @moduledoc """
  Functions that have no place to belong
  """

  @doc """
  Start a GenServer or Link if already started
  """
  @spec start_or_link(GenServer.on_start()) :: GenServer.on_start()
  def start_or_link({:error, {:already_started, pid}}) when is_pid(pid) do
    Process.link(pid)
    {:ok, pid}
  end

  def start_or_link(other) do
    other
  end

  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: Remove when gen_stage:0.12 support is dropped
  def gen_stage_v12? do
    Application.load(:gen_stage)

    Application.loaded_applications()
    |> Enum.find_value(nil, fn
      {:gen_stage, _, version} -> version
      _ -> false
    end)
    |> to_string
    |> Version.match?("< 0.13.0")
  end
end
