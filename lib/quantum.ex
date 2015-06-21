defmodule Quantum do

  use GenServer

  @typedoc "A cron expression"
  @type expr :: String.t | Atom

  @typedoc "A function/0 to be called when cron expression matches"
  @type fun0 :: (() -> Type)

  @typedoc "A job is defined by a cron expression and a function/0"
  @type job :: {expr, fun0}

  @doc "Adds a new job"
  @spec add_job(expr, fun0) :: :ok
  def add_job(e, fun) do
    GenServer.call(__MODULE__, {:add_job, Quantum.Normalizer.normalize({e, fun})})
  end

  @doc "Returns the list of currently defined jobs"
  @spec jobs :: [job]
  def jobs do
    GenServer.call(__MODULE__, :jobs)
  end

  def init(state) do
    tick
    {:ok, %{state | jobs: state.jobs |> Enum.filter(&reboot/1)}}
  end

  def handle_call({:add_job, job}, _from, state) do
    {:reply, :ok, %{state | jobs: [job | state.jobs]}}
  end

  def handle_call(:jobs, _from, state) do
    {:reply, state.jobs, state}
  end

  def handle_info(:tick, state) do
    {d, h, m} = tick
    if state.d != d, do: state = %{state | d: d, w: rem(:calendar.day_of_the_week(d), 7)}
    state = %{state | h: h, m: m}
    Enum.each state.jobs, &(Task.start Quantum.Executor, :execute, [&1, state])
    {:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}

  defp reboot({"@reboot", fun}), do: Task.start(fun) && false
  defp reboot(_), do: true

  defp tick do
    {d, {h, m, s}} = :calendar.now_to_universal_time(:os.timestamp)
    Process.send_after(self, :tick, (60 - s) * 1000)
    {d, h, m}
  end

end
