defmodule Quantum.Util do
  @moduledoc """
  Functions that have no place to belong
  """

  @doc """
  Start a GenServer or Link if already started
  """
  @spec start_or_link(GenServer.on_start) :: GenServer.on_start
  def start_or_link({:error, {:already_started, pid}}) when is_pid(pid) do
    Process.link(pid)
    {:ok, pid}
  end
  def start_or_link(other) do
    other
  end
end
