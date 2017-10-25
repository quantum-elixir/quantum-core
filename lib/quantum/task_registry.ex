defmodule Quantum.TaskRegistry do
  @moduledoc """
  Registry to check if a task is already running on a node.

  """
  use GenServer

  alias Quantum.Util

  @doc """
  Start the registry

  ### Options

    * `name` - Name of the registry

  """
  @spec start_link(GenServer.server()) :: GenServer.on_start()
  def start_link(name) do
    __MODULE__
    |> GenServer.start_link(%{}, name: name)
    |> Util.start_or_link()
  end

  @doc """
  Mark a task as Running

  ### Examples

      iex> Quantum.TaskRegistry.mark_running(server, running_job.name, self())
      :already_running

      iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, self())
      :marked_running

  """
  def mark_running(server, task, node) do
    GenServer.call(server, {:running, task, node})
  end

  @doc """
  Mark a task as Finished

  ### Examples

      iex> Quantum.TaskRegistry.mark_running(server, running_job.name, self())
      :ok

      iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, self())
      :ok

  """
  def mark_finished(server, task, node) do
    GenServer.cast(server, {:finished, task, node})
  end

  @doc false
  def handle_call({:running, task, node}, _caller, state) do
    if Enum.member?(Map.get(state, task, []), node) do
      {:reply, :already_running, state}
    else
      {:reply, :marked_running, Map.update(state, task, [node], &[node | &1])}
    end
  end

  @doc false
  def handle_cast({:finished, task, node}, state) do
    state = Map.update(state, task, [], &(&1 -- [node]))

    state =
      if Enum.empty?(Map.fetch!(state, task)) do
        Map.delete(state, task)
      else
        state
      end

    {:noreply, state}
  end
end
