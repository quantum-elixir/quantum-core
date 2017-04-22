defmodule Quantum.Executor do

  @moduledoc false

  def convert_to_timezone(date, :utc), do: date
  def convert_to_timezone(_, :local), do: raise "TZ local is no longer supported."
  def convert_to_timezone(date, tz) do
    date
    |> Calendar.NaiveDateTime.to_date_time_utc
    |> Calendar.DateTime.shift_zone!(tz)
    |> DateTime.to_naive
  end

  def execute({%Crontab.CronExpression{reboot: true}, fun, _}, %{reboot: true}), do: execute_fun(fun)
  def execute({%Crontab.CronExpression{reboot: false}, _, _}, %{reboot: true}), do: false

  def execute(job = {%Crontab.CronExpression{extended: false}, _, _}, state = %{date: %NaiveDateTime{second: 0}}) do
      _execute(job, state)
  end
  def execute(job = {%Crontab.CronExpression{extended: true}, _, _}, state) do
    _execute(job, state)
  end
  def execute(_, _), do: false

  defp _execute({cron_expression, fun, tz}, %{date: date}) do
    date_naive = convert_to_timezone(date, tz)

    if Crontab.DateChecker.matches_date?(cron_expression, date_naive) do
      execute_fun(fun)
    else
      false
    end
  end

  def execute_fun({mod, fun, args}) do
    mod = if is_binary(mod), do: String.to_atom("Elixir.#{mod}"), else: mod
    fun = if is_binary(fun), do: String.to_atom(fun), else: fun
    :erlang.apply(mod, fun, args)
  end

  def execute_fun(fun) when is_function(fun, 0), do: fun.()

end
