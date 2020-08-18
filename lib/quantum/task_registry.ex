defmodule Quantum.TaskRegistry do
  @moduledoc false

  # Registry to check if a task is already running on a node.

  use GenServer

  require Logger

  alias __MODULE__.{InitOpts, StartOpts, State}

  # Start the registry
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name}) do
    __MODULE__
    |> GenServer.start_link(%InitOpts{}, name: name)
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.monitor(pid)
        {:ok, pid}

      {:error, _reason} = error ->
        error
    end
  end

  # Mark a task as Running
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, running_job.name, self())
  #     :already_running
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, self())
  #     :marked_running
  def mark_running(server, task, node) do
    GenServer.call(server, {:running, task, node})
  end

  # Mark a task as Finished
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, running_job.name, self())
  #     :ok
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, self())
  #     :ok
  def mark_finished(server, task, node) do
    GenServer.cast(server, {:finished, task, node})
  end

  # Query if a task with given name is running
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.is_running?(server, running_job.name)
  #     true
  #
  #     iex> Quantum.TaskRegistry.is_running?(server, not_running_job.name)
  #     false
  def is_running?(server, task) do
    GenServer.call(server, {:is_running?, task})
  end

  # Query if any tasks are running in the cluster
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.any_running?(server_with_running_tasks)
  #     true
  #
  #     iex> Quantum.TaskRegistry.any_running?(server_without_running_tasks)
  #     false
  def any_running?(server) do
    GenServer.call(server, :any_running?)
  end

  @impl GenServer
  def init(%InitOpts{}) do
    {:ok, %State{running_tasks: %{}}}
  end

  @impl GenServer
  def handle_call({:running, task, node}, _caller, %State{running_tasks: running_tasks} = state) do
    if Enum.member?(Map.get(running_tasks, task, []), node) do
      {:reply, :already_running, state}
    else
      {:reply, :marked_running,
       %{state | running_tasks: Map.update(running_tasks, task, [node], &[node | &1])}}
    end
  end

  @impl GenServer
  def handle_call({:is_running?, task}, _caller, %State{running_tasks: running_tasks} = state) do
    case running_tasks do
      %{^task => [_ | _]} ->
        {:reply, true, state}

      %{^task => []} ->
        {:reply, false, state}

      %{} ->
        {:reply, false, state}
    end
  end

  @impl GenServer
  def handle_call(:any_running?, _caller, %State{running_tasks: running_tasks} = state) do
    if Enum.empty?(running_tasks) do
      {:reply, false, state}
    else
      {:reply, true, state}
    end
  end

  @impl GenServer
  def handle_cast({:finished, task, node}, %State{running_tasks: running_tasks} = state) do
    running_tasks =
      running_tasks
      |> Map.update(task, [], &(&1 -- [node]))
      |> case do
        %{^task => []} = still_running_tasks ->
          Map.delete(still_running_tasks, task)

        still_running_tasks ->
          still_running_tasks
      end

    {:noreply, %{state | running_tasks: running_tasks}}
  end

  @impl GenServer
  def handle_info(_message, state) do
    {:noreply, [], state}
  end
end
