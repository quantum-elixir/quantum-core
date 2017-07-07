defmodule Quantum.Executor do
  @moduledoc false

  alias Crontab.CronExpression
  alias Crontab.DateChecker

  @date_library Application.get_env(:quantum, :date_library, Quantum.DateLibrary.Timex)

  @typep job :: {Quantum.Job.schedule, Quantum.Job.task, Quantum.Job.timezone}
  @typep state :: %{date: NaiveDateTime.t, reboot: boolean}
  @typep executed :: boolean

  @doc """
  Execute a job if the date matches it's schedule.

  ### Parameters:

      * `job`
      * `state`
  """
  @spec execute(job, state) :: executed
  # On Reboot only execute reboot enabled cron expressions
  def execute({%CronExpression{reboot: true}, fun, _}, %{reboot: true}) do
    execute_task(fun)
    true
  end
  def execute(_, %{reboot: true}), do: false
  # Reboot enabled cron expressions run only on reboot, cancel
  def execute({%CronExpression{reboot: true}, _, _}, %{reboot: false}), do: false
  # Check Extended Expression every second
  def execute({%CronExpression{extended: true}, _, _} = job, state) do
    execute_task_if_date_matches(job, state)
  end
  # On Second 0 check all expressions
  def execute({%CronExpression{extended: false}, _, _} = job, %{date: %NaiveDateTime{second: 0}} = state) do
      execute_task_if_date_matches(job, state)
  end
  def execute({%CronExpression{extended: false}, _, _}, _), do: false

  @spec execute_task_if_date_matches(job, state) :: executed
  defp execute_task_if_date_matches({cron_expression, task, tz}, %{date: date}) do
    date_naive = convert_to_timezone(date, tz)

    if DateChecker.matches_date?(cron_expression, date_naive) do
      execute_task(task)
      true
    else
      false
    end
  end

  @spec execute_task(Quantum.Job.task) :: any
  defp execute_task({mod, fun, args}), do: :erlang.apply(mod, fun, args)
  defp execute_task(fun) when is_function(fun, 0), do: fun.()

  # Convert date to given TZ.
  #
  # * UTC: No Conversion
  # * Local: Not supported anymore
  # * Other: Convert via `Quantum.DateLibrary`
  @spec convert_to_timezone(NaiveDateTime.t, :utc) :: NaiveDateTime.t
  defp convert_to_timezone(date, :utc), do: date
  @spec convert_to_timezone(NaiveDateTime.t, :local) :: no_return
  defp convert_to_timezone(_, :local), do: raise "TZ local is no longer supported."
  @spec convert_to_timezone(NaiveDateTime.t, String.t) :: NaiveDateTime.t
  defp convert_to_timezone(date, tz), do: @date_library.utc_to_tz(date, tz)
end
