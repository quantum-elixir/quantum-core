defmodule Quantum do
  use GenServer
  import Process, only: [send_after: 3]

  @days   ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
  @months ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]  

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__] ++ options)
  end

  # Public functions ------------------------------------------------------------------------------

  def cron("@yearly",  fun),  do: GenServer.cast(__MODULE__, {"0 0 1 1 *", fun})
  def cron("@monthly", fun),  do: GenServer.cast(__MODULE__, {"0 0 1 * *", fun})
  def cron("@weekly",  fun),  do: GenServer.cast(__MODULE__, {"0 0 * * 0", fun})
  def cron("@daily",   fun),  do: GenServer.cast(__MODULE__, {"0 0 * * *", fun})
  def cron("@hourly",  fun),  do: GenServer.cast(__MODULE__, {"0 * * * *", fun})
  def cron(expression, fun),  do: GenServer.cast(__MODULE__, {expression,  fun})
  def reset,                  do: GenServer.cast(__MODULE__, :reset)

  # Private functions -----------------------------------------------------------------------------

  def init(_) do
    send_after(self, :tick, 1000)
    {:ok, %{jobs: [], d: nil, h: nil, m: nil, w: nil}}
  end

  def handle_info(:tick, state) do
    send_after(self, :tick, 1000)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    if state.d != d do
      state = %{state | w: rem(:calendar.day_of_the_week(d), 7)}
    end
    if state.m != m do
      state = %{state | d: d, h: h, m: m}
      Enum.each(state.jobs, fn({e, fun}) -> Task.start(__MODULE__, :execute, [e, fun, state]) end)
    end
    {:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}

  def handle_cast(:reset, state) do
    {:noreply, %{state | jobs: []}}
  end
  def handle_cast({ e, fun }, state) do
    {:noreply, %{state | jobs: ["#{e |> String.downcase |> translate}": fun] ++ state.jobs}}
  end

  def execute("* * * * *", fun, _), do: fun.()
  def execute("0 * * * *", fun, %{m: 0}), do: fun.()
  def execute("0 0 * * *", fun, %{m: 0, h: 0}), do: fun.()
  def execute("0 0 1 * *", fun, %{m: 0, h: 0, d: {_, _, 1}}), do: fun.()
  def execute("0 0 1 1 *", fun, %{m: 0, h: 0, d: {_, 1, 1}}), do: fun.()
  def execute(e, fun, state) do
    [m, h, d, n, w] = e |> String.split(" ")
    {_, cur_mon, cur_day} = state.d
    cond do
      !match(m, state.m, 0, 59) -> false
      !match(h, state.h, 0, 59) -> false
      !match(d, cur_day, 1, 31) -> false
      !match(n, cur_mon, 1, 12) -> false
      !match(w, state.w, 0,  6) -> false
      true                      -> fun.()
    end
  end

  defp translate(e) do
    {e,_} = List.foldl(@days,   {e,0}, fn(x, acc) -> translate(acc, x) end)
    {e,_} = List.foldl(@months, {e,1}, fn(x, acc) -> translate(acc, x) end)
    e
  end
  defp translate({e, i}, term), do: {String.replace(e, term, "#{i}"), i+1}

  defp match("*", _, _, _), do: true
  defp match([], _, _, _), do: false
  defp match([e|t], v, min, max), do: Enum.any?(parse(e, min, max), &(&1 == v)) or match(t, v, min, max)
  defp match(e, v, min, max), do: match(e |> String.split(","), v, min, max)

  defp parse("*/" <> _ = e, min, max) do
    [_,i] = e |> String.split("/")
    {x,_} = i |> Integer.parse
    Enum.reject(min..max, &(rem(&1, x) != 0))
  end
  defp parse(e, min, max) do
    [r|i] = e |> String.split("/")
    [x|y] = r |> String.split("-")
    {v,_} = x |> Integer.parse
    parse(v, y, i, min, max) |> Enum.reject(&((&1 < min) or (&1 > max)))
  end
  defp parse(v, [], [], _, _), do: [v]
  defp parse(v, [], i, _, _) do
    {x,_} = i |> Integer.parse
    [rem(v,i)]
  end
  defp parse(v, y, [], min, max) do
    {t,_} = y |> Integer.parse
    if v < t do
      Enum.to_list(v..t)
    else
      Enum.to_list(v..max) ++ Enum.to_list(min..t)
    end
  end
  defp parse(v, y, i, min, max) do
    {x, _} = i |> Integer.parse
    parse(v, y, [], min, max) |> Enum.reject(&(rem(&1, x) != 0))
  end

end
