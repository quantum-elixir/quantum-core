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

  @quantum if Application.get_env(:quantum, :global?, false),
              do: {:global, Quantum},
              else: Quantum

  @doc "Adds a new unnamed job"
  @spec add_job(job) :: :ok
  def add_job(job) do
    GenServer.call(@quantum, {:add, Normalizer.normalize({nil, job})}, timeout())
  end

  @doc "Adds a new named job"
  @spec add_job(expr, job) :: :ok | :error
  def add_job(expr, job) do
    {name, job} = Normalizer.normalize({expr, job})
    if name && find_job(name) do
      :error
    else
      GenServer.call(@quantum, {:add, {name, job}}, timeout())
    end
  end

  @doc "Deactivates a job by name"
  @spec deactivate_job(expr) :: :ok
  def deactivate_job(n) do
    GenServer.call(@quantum, {:change_state, n, :inactive}, timeout())
  end

  @doc "Activates a job by name"
  @spec activate_job(expr) :: :ok
  def activate_job(n) do
    GenServer.call(@quantum, {:change_state, n, :active}, timeout())
  end

  @doc "Resolves a job by name"
  @spec find_job(expr) :: job
  def find_job(name) do
    find_by_name(jobs(), name)
  end

  @doc "Deletes a job by name"
  @spec delete_job(expr) :: job
  def delete_job(name) do
    GenServer.call(@quantum, {:delete, name}, timeout())
  end

  @doc "Deletes all jobs"
  @spec delete_all_jobs :: :ok
  def delete_all_jobs do
    GenServer.call(@quantum, {:delete_all}, timeout())
  end

  @doc "Returns the list of currently defined jobs"
  @spec jobs :: [job]
  def jobs do
    GenServer.call(@quantum, :jobs, timeout())
  end

  @doc "Starts Quantum process"
  def start_link(state) do
    case GenServer.start_link(__MODULE__, state, [name: @quantum]) do
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
    s = if s.d != d, do: %{s | d: d, w: rem(:calendar.day_of_the_week(d), 7)}, else: s
    s = %{s | h: h, m: m}
    {:noreply, %{s | jobs: run(s)}}
  end
  def handle_info(_, s), do: {:noreply, s}

  defp run(state) do
    Enum.map state.jobs, fn({name, job}) ->
      if Job.executable?(job) do
        task = Task.Supervisor.async_nolink(:quantum_tasks_sup, Quantum.Executor,
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

  defp timeout, do: Application.get_env(:quantum, :timeout, 5_000)

end
