defmodule Quantum do
  use GenServer
  import Process, only: [send_after: 3]

  @typedoc "A function/0 to be called when cron expression matches"
  @type fun0 :: (() -> Type)
  @typedoc "A job is defined by a cron expression and a function/0"
  @type job :: {String.t | Atom, fun0}

  @doc "Adds a new job"
  @spec add_job(String.t, fun0) :: :ok
  def add_job(spec, job) do
    GenServer.call(__MODULE__, {:add_job, spec, job})
  end

  @doc "Returns the list of currently defined jobs"
  @spec jobs :: [job]
  def jobs do
    GenServer.call(__MODULE__, :jobs)
  end

  def init(_) do
    tick
    {:ok, %{jobs: Application.get_env(:quantum, :cron, []), d: nil, h: nil, m: nil, w: nil}}
  end

  def handle_call({:add_job, spec, job}, _from, state) do
    {:reply, :ok, %{state | jobs: [{spec, job} | state.jobs]}}
  end

  def handle_call(:jobs, _from, state) do
    {:reply, state.jobs, state}
  end

  def handle_info(:tick, state) do
    {d, h, m} = tick
    if state.d != d, do: state = %{state | d: d, w: rem(:calendar.day_of_the_week(d), 7)}
    state = %{state | h: h, m: m}
    Enum.each(state.jobs, fn({e, fun}) -> execute(e, fun, state) end)
    {:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}

  defp execute(e, fun, state) do
    Task.start(Quantum.Executor, :execute, [e, fun, state])
  end

  defp tick do
    {d, {h, m, s}} = :calendar.now_to_universal_time(:os.timestamp)
    send_after(self, :tick, (60 - s) * 1000)
    {d, h, m}
  end

end
