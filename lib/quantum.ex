defmodule Quantum do

  use GenServer

  @typedoc "A cron expression"
  @type expr :: String.t | Atom

  @typedoc "A function/0 to be called when cron expression matches"
  @type fun0 :: (() -> Type)

  @typedoc "A job is defined by a cron expression and a function/0"
  @type job :: {atom, Quantum.Job.t}

  @doc "Adds a new job"
  @spec add_job(job) :: :ok
  def add_job(job) do
    GenServer.call(Quantum, {:add, {nil, job}})
  end

  @spec add_job(expr, job) :: :ok
  def add_job(name, %Quantum.Job{} = job) do
    job = %{job | name: name}
    GenServer.call(Quantum, {:add, {name, job}})
  end

  @spec add_job(expr, fun0) :: :ok
  def add_job(e, fun) do
    GenServer.call(Quantum, {:add, Quantum.Normalizer.normalize({e, fun})})
  end

  @spec suspend_job(atom) :: :ok
  def suspend_job(n) do
    GenServer.call(Quantum, {:change_state, n, :suspended})
  end

  @spec activate_job(atom) :: :ok
  def activate_job(n) do
    GenServer.call(Quantum, {:change_state, n, :active})
  end

  @spec find_job(atom) :: job
  def find_job(name) do
    Keyword.get(jobs, name)
  end

  @spec delete_job(atom) :: job
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
    Quantum.Timer.tick
    {:ok, %{s | jobs: run(%{s | r: 1}), r: 0}}
  end

  def handle_call({:add, j}, _, s), do: {:reply, :ok, %{s | jobs: [j | s.jobs]}}

  def handle_call({:change_state, n, js}, _, s) do
    jobs = Enum.map(s.jobs, fn({jn, j}) ->
      case jn do
        ^n -> {jn, %{j | state: js}}
        _ -> {jn, j}
      end
    end)
    {:reply, :ok, %{s | jobs: jobs}}
  end

  def handle_call({:delete, n}, _, s) do
    job = case Keyword.get(s.jobs, n) do
      nil -> nil
      job ->
        s = %{s | jobs: Keyword.delete(s.jobs, n)}
        job
    end
    {:reply, job, s}
  end

  def handle_call(:jobs, _, s), do: {:reply, s.jobs, s}
  def handle_call(:which_children, _, s) do
    children = [{Task.Supervisor, :quantum_tasks_sup, :supervisor, [Task.Supervisor]}]
    {:reply, children, s}
  end

  def handle_info(:tick, s) do
    {d, h, m} = Quantum.Timer.tick
    if s.d != d, do: s = %{s | d: d, w: rem(:calendar.day_of_the_week(d), 7)}
    s = %{s | h: h, m: m}
    {:noreply, %{s | jobs: run(s)}}
  end
  def handle_info(_, s), do: {:noreply, s}

  defp run(s) do
    Enum.each s.jobs, fn({_name, j}) ->
      if j.state == :active do
        Task.Supervisor.async(:quantum_tasks_sup, Quantum.Executor, :execute,
                                                  [{j.schedule, j.task, j.args}, s])
      end
    end
    s.jobs
  end

end
