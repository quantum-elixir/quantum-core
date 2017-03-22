defmodule Quantum.Scheduler do
  @moduledoc false

  use GenServer

  alias Quantum.Job
  alias Quantum.Timer

  @doc "Starts Quantum process"
  def start_link(opts) do
    state = %{opts: opts, jobs: Keyword.fetch!(opts, :cron), d: nil, h: nil, m: nil, s: nil, w: nil, r: nil}
    case GenServer.start_link(__MODULE__, state, [name: Keyword.fetch!(opts, :scheduler)]) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Process.link(pid)
        {:ok, pid}
    end
  end

  def init(s) do
    Timer.tick
    {:ok, %{s | jobs: run(%{s | r: 1}), r: 0}}
  end

  def handle_call({:add, j}, _, s), do: {:reply, :ok, %{s | jobs: [j | s.jobs]}}

  def handle_call({:change_state, n, js}, _, s) do
    new_jobs = Enum.map(s.jobs, fn({jn, j}) ->
      case jn do
        ^n -> {jn, %{j | state: js}}
        _ -> {jn, j}
      end
    end)
    {:reply, :ok, %{s | jobs: new_jobs}}
  end

  def handle_call({:delete, n}, _, s) do
    {job, s} = case find_by_name(s.jobs, n) do
      nil -> {nil, s}
      job -> {job, %{s | jobs: List.keydelete(s.jobs, n, 0)}}
    end
    {:reply, job, s}
  end

  def handle_call({:delete_all}, _, s) do
    {:reply, :ok, %{s | jobs: []}}
  end

  def handle_call(:jobs, _, s), do: {:reply, s.jobs, s}

  def handle_call({:find_job, name}, _, s = %{jobs: jobs}) do
    {:reply, find_by_name(jobs, name), s}
  end

  def handle_call(:which_children, _, s) do
    children = [{
      Task.Supervisor,
      :quantum_tasks_sup,
      :supervisor,
      [Task.Supervisor]
    }]
    {:reply, children, s}
  end

  def handle_info(:tick, state) do
    {d, h, m, s} = Timer.tick
    state1 = if state.d != d, do: %{state | d: d, w: rem(:calendar.day_of_the_week(d), 7)}, else: state
    state2 = %{state1 | h: h, m: m, s: s}
    {:noreply, %{state2 | jobs: run(state2)}}
  end
  def handle_info(_, s), do: {:noreply, s}

  defp run(state) do
    Enum.map state.jobs, fn({name, job}) ->
      if Job.executable?(job) do
        task = Task.Supervisor.async_nolink(Keyword.fetch!(state.opts, :task_supervisor), Quantum.Executor,
            :execute, [{job.schedule, job.task, job.args, job.timezone}, state])
        {name, %{job | pid: task.pid}}
      else
        {name, job}
      end
    end
  end

  defp find_by_name(job_list, job_name) do
    case List.keyfind(job_list, job_name, 0) do
      nil          -> nil
      {_name, job} -> job
    end
  end
end
