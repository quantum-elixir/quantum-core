defmodule Quantum do
  use GenServer
  import Process, only: [send_after: 3]
  import Quantum.Parser
  import Quantum.Translator

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
    Enum.each(state.jobs, fn({e, fun}) -> Task.start(__MODULE__, :execute, [e, fun, state]) end)
    {:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}

  @doc false
  def execute(e, fun, state) when e |> is_atom do
    execute(e |> Atom.to_string |> String.downcase |> translate, fun, state)
  end
  @doc false
  def execute("* * * * *", fun, _), do: fun.()
  @doc false
  def execute("@hourly",   fun, %{m: 0}), do: fun.()
  @doc false
  def execute("0 * * * *", fun, %{m: 0}), do: fun.()
  @doc false
  def execute("@daily",    fun, %{m: 0, h: 0}), do: fun.()
  @doc false
  def execute("0 0 * * *", fun, %{m: 0, h: 0}), do: fun.()
  @doc false
  def execute("@weekly",   fun, %{m: 0, h: 0, w: 0}), do: fun.()
  @doc false
  def execute("0 0 * * 0", fun, %{m: 0, h: 0, w: 0}), do: fun.()
  @doc false
  def execute("@monthly",  fun, %{m: 0, h: 0, d: {_, _, 1}}), do: fun.()
  @doc false
  def execute("0 0 1 * *", fun, %{m: 0, h: 0, d: {_, _, 1}}), do: fun.()
  @doc false
  def execute("@yearly",   fun, %{m: 0, h: 0, d: {_, 1, 1}}), do: fun.()
  @doc false
  def execute("0 0 1 1 *", fun, %{m: 0, h: 0, d: {_, 1, 1}}), do: fun.()
  @doc false
  def execute("@hourly",   _, _), do: false
  @doc false
  def execute("@daily",    _, _), do: false
  @doc false
  def execute("@weekly",   _, _), do: false
  @doc false
  def execute("@yearly",   _, _), do: false
  @doc false
  def execute("@monthly",  _, _), do: false
  @doc false
  def execute(e, fun, state) do
    [m, h, d, n, w] = e |> String.split(" ")
    {_, cur_mon, cur_day} = state.d
    cond do
      !match(m, state.m, 0, 59) -> false
      !match(h, state.h, 0, 24) -> false
      !match(d, cur_day, 1, 31) -> false
      !match(n, cur_mon, 1, 12) -> false
      !match(w, state.w, 0,  6) -> false
      true                      -> fun.()
    end
  end

  defp match("*", _, _, _), do: true
  defp match([], _, _, _), do: false
  defp match([e|t], v, min, max), do: Enum.any?(parse(e, min, max), &(&1 == v)) or match(t, v, min, max)
  defp match(e, v, min, max), do: match(e |> String.split(","), v, min, max)

  defp tick do
    {d, {h, m, s}} = :calendar.now_to_universal_time(:os.timestamp)
    send_after(self, :tick, (60 - s) * 1000)
    {d, h, m}
  end

end
