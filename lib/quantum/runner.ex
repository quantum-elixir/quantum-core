defmodule Quantum.Runner do
  @moduledoc false

  use GenServer

  alias Quantum.Job
  alias Quantum.Timer
  alias Quantum.RunStrategy.NodeList

  require Logger

  @doc """
  Starts Quantum process
  """
  def start_link(opts) do
    state = %{opts: opts, jobs: Keyword.fetch!(opts, :jobs), reboot: true}
    case GenServer.start_link(__MODULE__, state, [name: Keyword.fetch!(opts, :runner)]) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Process.link(pid)
        {:ok, pid}
    end
  end

  def init(state) do
    new_state = state
    |> Map.put(:jobs, run(state))
    |> Map.put(:date, Timer.tick())
    |> Map.put(:reboot, false)

    {:ok, new_state}
  end

  def handle_call({:add, job}, _, state = %{jobs: jobs}) do
    {:reply, :ok, %{state | jobs: [job | jobs]}}
  end

  def handle_call({:change_state, name, job_state}, _, state = %{jobs: jobs}) do
    if Keyword.has_key?(jobs, name) do
      job = jobs
      |> Keyword.fetch!(name)
      |> Job.set_state(job_state)

      new_jobs = Keyword.put(jobs, name, job)

      {:reply, :ok, %{state | jobs: new_jobs}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete, name}, _, state = %{jobs: jobs}) do
    if Keyword.has_key?(jobs, name) do
      {:reply, :ok, %{state | jobs: List.keydelete(jobs, name, 0)}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete_all}, _, state) do
    {:reply, :ok, %{state | jobs: []}}
  end

  def handle_call(:jobs, _, state = %{jobs: jobs}), do: {:reply, jobs, state}

  def handle_call({:find_job, name}, _, state = %{jobs: jobs}) do
    {:reply, Keyword.get(jobs, name), state}
  end

  def handle_info(:tick, state) do
    new_state = Map.put(state, :date, Timer.tick())
    {:noreply, %{new_state | jobs: run(new_state)}}
  end
  def handle_info(_, state), do: {:noreply, state}

  defp run(state) do
    task_supervisor = Keyword.fetch!(state.opts, :task_supervisor)
    Enum.map state.jobs, fn({name, job}) ->
      pids = job.run_strategy
      |> NodeList.nodes(job)
      |> Enum.filter(&running_node?(&1, task_supervisor))
      |> Enum.map(&run_if_possible(&1, job, state, task_supervisor))
      |> Enum.reject(fn ({_, pid}) -> pid == nil end)
      |> Enum.reduce(job.pids, fn({node, pid}, acc) ->
        Keyword.put(acc, node, pid)
      end)
      {name, %{job | pids: pids}}
    end
  end

  defp running_node?(node, _) when node == node(), do: true
  defp running_node?(node, task_supervisor) do
    node
    |> :rpc.call(:erlang, :whereis, [task_supervisor])
    |> is_pid()
  end

  defp run_if_possible(node, job, state, task_supervisor) do
    cond do
      !Job.executable?(job, node) ->
        {node, Keyword.get(job.pids, node, nil)}
      !Enum.member?([node() | Node.list()], node) ->
        Logger.warn("Node #{inspect node} is not in cluster. Skipping.")
        {node, Keyword.get(job.pids, node, nil)}
      true ->
        task = Task.Supervisor.async_nolink({task_supervisor, node}, Quantum.Executor,
            :execute, [{job.schedule, job.task, job.timezone}, state])
        {node, task.pid}
    end
  end
end
