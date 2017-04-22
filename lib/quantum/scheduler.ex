defmodule Quantum.Scheduler do
  @moduledoc false

  use GenServer

  alias Quantum.Job
  alias Quantum.Timer

  @doc """
  Starts Quantum process
  """
  def start_link(opts) do
    state = %{opts: opts, jobs: Keyword.fetch!(opts, :jobs), reboot: true}
    case GenServer.start_link(__MODULE__, state, [name: Keyword.fetch!(opts, :scheduler)]) do
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
    Enum.map state.jobs, fn({name, job}) ->
      if Job.executable?(job) do
        task = Task.Supervisor.async_nolink(Keyword.fetch!(state.opts, :task_supervisor), Quantum.Executor,
            :execute, [{job.schedule, job.task, job.timezone}, state])
        {name, %{job | pid: task.pid}}
      else
        {name, job}
      end
    end
  end
end
