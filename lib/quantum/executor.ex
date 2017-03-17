defmodule Quantum.Executor do

  @moduledoc false

  def convert_to_timezone(s, tz) do
    dt = {s.d, {s.h, s.m, s.s}}  # erlang datetime

    tz_final = case tz do
      :utc   -> "Etc/UTC"
      :local -> raise "error - local timezone not allowed"
      tz0    -> tz0
    end

    case Application.get_env(:quantum, :timezone, :utc) do
      :utc   -> dt |> Calendar.DateTime.from_erl!("Etc/UTC") |> Calendar.DateTime.shift_zone!(tz_final)
      :local -> raise "error - local timezone not allowed"
      _      -> dt |> Calendar.DateTime.from_erl!(tz_final)
    end
  end

  def execute({%Crontab.CronExpression{reboot: true}, fun, args, _}, %{r: 1}), do: execute_fun(fun, args)
  def execute(_, %{r: 1}), do: false
  def execute({%Crontab.CronExpression{reboot: true}, _, _, _}, %{r: 0}), do: false

  def execute(job = {%Crontab.CronExpression{extended: false}, _, _, _}, state = %{s: 0}) do
      _execute(job, state)
  end
  def execute(job = {%Crontab.CronExpression{extended: true}, _, _, _}, state) do
    _execute(job, state)
  end
  def execute(_, _), do: false

  defp _execute({cron_expression, fun, args, tz}, state) do
    date_naive = state
      |> convert_to_timezone(tz)
      |> DateTime.to_naive

    if Crontab.DateChecker.matches_date?(cron_expression, date_naive) do
      execute_fun(fun, args)
    else
      false
    end
  end

  defp execute_fun({mod, fun}, args) do
    mod = if is_binary(mod), do: String.to_atom("Elixir.#{mod}"), else: mod
    fun = if is_binary(fun), do: String.to_atom(fun), else: fun
    :erlang.apply(mod, fun, args)
  end

  defp execute_fun(fun, args), do: :erlang.apply(fun, args)

end
