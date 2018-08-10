defmodule Quantum.TaskRegistry do
  @moduledoc """
  Registry to check if a task is already running on a node.

  """
  use GenServer

  require Logger

  @doc """
  Start the registry

  ### Options

    * `name` - Name of the registry

  """
  @spec start_link(GenServer.server()) :: GenServer.on_start()
  def start_link(name) do
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc false
  @spec child_spec(Keyword.t() | GenServer.server()) :: Supervisor.child_spec()
  def child_spec(opts) when is_list(opts) do
    %{
      super(opts)
      | start: {
          __MODULE__,
          :start_link,
          [Keyword.fetch!(opts, :name)]
        }
    }
  end

  def child_spec(name), do: child_spec(name: name)

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

  @doc """
  Query if a task with given name is running

  ### Examples

      iex> Quantum.TaskRegistry.is_running?(server, running_job.name)
      true

      iex> Quantum.TaskRegistry.is_running?(server, not_running_job.name)
      false

  """
  def is_running?(server, task) do
    GenServer.call(server, {:is_running?, task})
  end

  @doc """
  Query if any tasks are running in the cluster

  ### Examples

      iex> Quantum.TaskRegistry.any_running?(server_with_running_tasks)
      true

      iex> Quantum.TaskRegistry.any_running?(server_without_running_tasks)
      false

  """
  def any_running?(server) do
    GenServer.call(server, :any_running?)
  end

  @doc false
  def init(args) do
    {:ok, args}
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
  def handle_call({:is_running?, task}, _caller, state) do
    if Enum.empty?(Map.get(state, task, [])) do
      {:reply, false, state}
    else
      {:reply, true, state}
    end
  end

  @doc false
  def handle_call(:any_running?, _caller, state) do
    if Enum.empty?(state) do
      {:reply, false, state}
    else
      {:reply, true, state}
    end
  end

  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Handing of state to other cluster node"
    end)

    {:reply, {:resume, state}, state}
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

  def handle_cast({:swarm, :end_handoff, handoff_state}, state) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Incorperating state from other cluster node"
    end)

    {:noreply, merge_states(state, handoff_state)}
  end

  def handle_cast({:swarm, :resolve_conflict, handoff_state}, state) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Incorperating conflict state from other cluster node"
    end)

    {:noreply, merge_states(state, handoff_state)}
  end

  defp merge_states(state1, state2) do
    state1
    |> Enum.into([])
    |> Kernel.++(Enum.into(state2, []))
    |> Enum.group_by(fn {job, _nodes_list} -> job end, fn {_job, nodes_list} -> nodes_list end)
    |> Enum.into(%{}, fn {job, nodes_list_list} ->
      {job, List.flatten(nodes_list_list)}
    end)
  end

  def handle_info({:swarm, :die}, state) do
    {:stop, :shutdown, state}
  end
end
