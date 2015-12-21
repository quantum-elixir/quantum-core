defmodule Quantum do

  @moduledoc "A cron-like job scheduler"

  alias Quantum.Job
  alias Quantum.Normalizer
  alias Quantum.Timer

  use GenServer

  @typedoc "A cron expression"
  @type expr :: String.t | Atom

  @typedoc "A function/0 to be called when cron expression matches"
  @type fun0 :: (() -> Type)

  @typedoc "A job is defined by a cron expression and a task"
  @type job :: {atom, Job.t}

  @typedoc "A job options can be defined as list or map"
  @type opts :: list | map | fun0

  @doc "Adds a new unnamed job"
  @spec add_job(job) :: :ok
  def add_job(job) do
    GenServer.call(Quantum, {:add, Normalizer.normalize({nil, job})})
  end

  @doc "Adds a new named job"
  @spec add_job(expr, job) :: :ok
  def add_job(expr, job) do
    GenServer.call(Quantum, {:add, Normalizer.normalize({expr, job})})
  end

  @doc "Deactivates a job by name"
  @spec deactivate_job(expr) :: :ok
  def deactivate_job(n) do
    GenServer.call(Quantum, {:change_state, n, :inactive})
  end

  @doc "Activates a job by name"
  @spec activate_job(expr) :: :ok
  def activate_job(n) do
    GenServer.call(Quantum, {:change_state, n, :active})
  end

  @doc "Resolves a job by name"
  @spec find_job(expr) :: job
  def find_job(name) do
    find_by_name(jobs, name)
  end

  @doc "Deletes a job by name"
  @spec delete_job(expr) :: job
  def delete_job(name) do
    GenServer.call(Quantum, {:delete, name})
  end

  @doc "Returns the list of currently defined jobs"
  @spec jobs :: [job]
  def jobs do
    GenServer.call(Quantum, :jobs)
  end

  @doc "Starts Quantum process"
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, [name: Quantum])
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
    job = case find_by_name(s.jobs, n) do
      nil -> nil
      job ->
        s = %{s | jobs: List.keydelete(s.jobs, n, 0)}
        job
    end
    {:reply, job, s}
  end

  def handle_call(:jobs, _, s), do: {:reply, s.jobs, s}
  def handle_call(:which_children, _, s) do
    children = [{
      Task.Supervisor,
      :quantum_tasks_sup,
      :supervisor,
      [Task.Supervisor]
    }]
    {:reply, children, s}
  end

  def handle_info(:tick, s) do
    {d, h, m} = Timer.tick
    if s.d != d, do: s = %{s | d: d, w: rem(:calendar.day_of_the_week(d), 7)}
    s = %{s | h: h, m: m}
    {:noreply, %{s | jobs: run(s)}}
  end
  def handle_info(_, s), do: {:noreply, s}

  defp run(s) do
    Enum.map s.jobs, fn({name, j}) ->
      if j.state == :active && node() in j.nodes && check_overlap(j) do
        t = Task.Supervisor.async(:quantum_tasks_sup, Quantum.Executor,
                                  :execute, [{j.schedule, j.task, j.args}, s])
        {name, %{j | pid: t.pid}}
      else
        {name, j}
      end
    end
  end

  defp check_overlap(job) do
    cond do
      job.overlap == true     -> true  # Overlapping is always ok
      job.pid == nil          -> true  # Job has not been started before
      Process.alive?(job.pid) -> false # Previous job is still running
      true                    -> true  # Previous job has finished
    end
  end

  defp find_by_name(job_list, job_name) do
    case List.keyfind(job_list, job_name, 0) do
      nil          -> nil
      {_name, job} -> job
    end
  end

end
