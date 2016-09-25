defmodule Quantum.Executor do

  @moduledoc false

  alias Timex.Timezone
  import Quantum.Matcher

  def convert_to_timezone(s, tz) do
    t = {s.d, {s.h, s.m, 0}}  # Convert to erlang datetime
    tz_final = case tz do
      :utc   -> Timezone.get("UTC")
      :local -> Timezone.local()
      tz0    -> tz0
    end

    case Application.get_env(:quantum, :timezone, :utc) do
      :utc   -> t |> Timex.to_datetime |> Timezone.convert(tz_final)
      :local -> t |> Timex.to_datetime(:local) |> Timezone.convert(tz_final)
      tz     ->
        t |> Timex.to_datetime(tz_final)
    end
  end

  def execute({"@reboot",   fun, args, _}, %{r: 1}), do: execute_fun(fun, args)
  def execute(_,                           %{r: 1}), do: false
  def execute({"@reboot",   _, _, _},      %{r: 0}), do: false
  def execute({"* * * * *", fun, args, _}, _), do: execute_fun(fun, args)

  def execute({"@hourly", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0, do: execute_fun(fun, args), else: false
  end

  def execute({"@daily", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0 and c.hour == 0, do: execute_fun(fun, args), else: false
  end

  def execute({"@midnight", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0 and c.hour == 0, do: execute_fun(fun, args), else: false
  end

  def execute({"@weekly", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    c_weekday = rem(Timex.weekday(c), 7)
    if c.minute == 0 and c.hour == 0 and c_weekday == 0 do
      execute_fun(fun, args)
    else
      false
    end
  end

  def execute({"@monthly", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0 and c.hour == 0 and c.day == 1 do
      execute_fun(fun, args)
    else
      false
    end
  end

  def execute({"@annually", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0 and c.hour == 0 and c.day == 1 and c.month == 1 do
      execute_fun(fun, args)
    else
      false
    end
  end

  def execute({"@yearly", fun, args, tz}, state) do
    c = convert_to_timezone(state, tz)
    if c.minute == 0 and c.hour == 0 and c.day == 1 and c.month == 1 do
      execute_fun(fun, args)
    else
      false
    end
  end

  def execute({e, fun, args, tz}, state) do
    [m, h, d, n, w] = e |> String.split(" ")

    c = convert_to_timezone(state, tz)
    c_weekday = rem(Timex.weekday(c), 7)

    cond do
      !match(m, c.minute,  0..59) -> false
      !match(h, c.hour,    0..23) -> false
      !match(d, c.day,     1..31) -> false
      !match(n, c.month,   1..12) -> false
      !match(w, c_weekday, 0..6)  -> false
      true                        -> execute_fun(fun, args)
    end
  end

  defp execute_fun({mod, fun}, args) do
    mod = if is_binary(mod), do: String.to_atom("Elixir.#{mod}"), else: mod
    fun = if is_binary(fun), do: String.to_atom(fun), else: fun
    :erlang.apply(mod, fun, args)
  end

  defp execute_fun(fun, args), do: :erlang.apply(fun, args)

end
