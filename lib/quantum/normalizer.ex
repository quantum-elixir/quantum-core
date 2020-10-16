defmodule Quantum.Normalizer do
  @moduledoc false

  # Normalize Config values into a `Quantum.Job`.

  alias Crontab.CronExpression
  alias Crontab.CronExpression.Parser, as: CronExpressionParser

  alias Quantum.{
    Job,
    RunStrategy.NodeList
  }

  @type config_short_notation :: {config_schedule, config_task}
  @type config_full_notation :: {config_name | nil, Keyword.t() | map}

  @type config_schedule ::
          CronExpression.t() | String.t() | {:cron, String.t()} | {:extended, String.t()}
  @type config_task :: {module, fun, [any]} | (() -> any)
  @type config_name :: String.t() | atom

  # Normalize Config Input into `Quantum.Job`.
  #
  # ### Parameters:
  #
  #   * `base` - Empty `Quantum.Job`
  #   * `job` - The Job To Normalize
  @spec normalize(Job.t(), config_full_notation | config_short_notation | Job.t()) ::
          Job.t() | no_return
  def normalize(base, job)

  def normalize(%Job{} = base, job) when is_list(job) do
    normalize_options(base, Map.new(job))
  end

  def normalize(%Job{} = base, {job_name, opts}) when is_list(opts) do
    normalize(base, {job_name, Map.new(opts)})
  end

  def normalize(%Job{} = base, {nil, opts}) when is_map(opts) do
    normalize_options(base, opts)
  end

  def normalize(%Job{} = base, {job_name, opts}) when is_map(opts) do
    opts = Map.put(opts, :name, job_name)

    normalize_options(base, opts)
  end

  def normalize(%Job{} = base, {schedule, task}) do
    normalize_options(base, %{schedule: schedule, task: task})
  end

  def normalize(%Job{} = _base, %Job{} = job) do
    job
  end

  @spec normalize_options(Job.t(), map) :: Job.t()
  defp normalize_options(job, options) do
    Enum.reduce(options, job, &normalize_job_option/2)
  end

  @spec normalize_job_option({atom, any}, Job.t()) :: Job.t()
  defp normalize_job_option({:name, name}, job) do
    Job.set_name(job, normalize_name(name))
  end

  defp normalize_job_option({:schedule, schedule}, job) do
    Job.set_schedule(job, normalize_schedule(schedule))
  end

  defp normalize_job_option({:task, task}, job) do
    Job.set_task(job, normalize_task(task))
  end

  defp normalize_job_option({:run_strategy, run_strategy}, job) do
    Job.set_run_strategy(job, normalize_run_strategy(run_strategy))
  end

  defp normalize_job_option({:overlap, overlap}, job) do
    Job.set_overlap(job, overlap)
  end

  defp normalize_job_option({:timezone, timezone}, job) do
    Job.set_timezone(job, normalize_timezone(timezone))
  end

  defp normalize_job_option({:state, state}, job) do
    Job.set_state(job, state)
  end

  defp normalize_job_option(_, job), do: job

  @spec normalize_task(config_task) :: Job.task() | no_return
  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task(fun) when is_function(fun, 0), do: fun

  defp normalize_task(fun) when is_function(fun),
    do: raise("Only 0 arity functions are supported via the short syntax.")

  @spec normalize_schedule(config_schedule) :: Job.schedule() | no_return
  def normalize_schedule(nil), do: nil
  def normalize_schedule(%CronExpression{} = e), do: e

  def normalize_schedule(e) when is_binary(e),
    do: e |> String.downcase() |> CronExpressionParser.parse!()

  def normalize_schedule({:cron, e}) when is_binary(e),
    do: e |> String.downcase() |> CronExpressionParser.parse!()

  def normalize_schedule({:extended, e}) when is_binary(e),
    do: e |> String.downcase() |> CronExpressionParser.parse!(true)

  @spec normalize_name(atom | String.t()) :: atom
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)
  defp normalize_name(name) when is_atom(name), do: name

  @spec normalize_run_strategy({module, any} | module) :: NodeList
  defp normalize_run_strategy(strategy) when is_atom(strategy) do
    strategy.normalize_config!(nil)
  end

  defp normalize_run_strategy({strategy, options}) when is_atom(strategy) do
    strategy.normalize_config!(options)
  end

  @spec normalize_timezone(String.t() | :utc) :: String.t() | :utc
  defp normalize_timezone(timezone) when is_binary(timezone), do: timezone
  defp normalize_timezone(:utc), do: :utc
  defp normalize_timezone(timezone), do: raise("Invalid timezone: #{inspect(timezone)}")
end
