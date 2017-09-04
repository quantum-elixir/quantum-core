defmodule Quantum.Normalizer do
  @moduledoc """
  Normalize Config values into a `Quantum.Job`.
  """

  alias Quantum.Job
  alias Crontab.CronExpression.Parser, as: CronExpressionParser
  alias Crontab.CronExpression
  alias Quantum.RunStrategy.NodeList

  @fields [:name,
           :schedule,
           :task,
           :overlap,
           :run_strategy,
           :timezone]

  @type config_short_notation :: {config_schedule, config_task}
  @type config_full_notation :: {config_name | nil, Keyword.t | map}

  @typep field :: :name | :schedule | :task | :overlap | :run_strategy
  @type config_schedule :: CronExpression.t | String.t | {:cron, String.t} | {:extended, String.t}
  @type config_task :: {module, fun, [any]} | (() -> any)
  @type config_name :: String.t | atom

  @doc """
  Normalize Config Input into `Quantum.Job`.

  ### Parameters:

    * `base` - Empty `Quantum.Job`
    * `job` - The Job To Normalize

  """
  @spec normalize(Job.t, config_full_notation | config_short_notation) :: Job.t | no_return
  def normalize(base, job)
  def normalize(%Job{} = base, job) when is_list(job) do
    normalize_options(base, job |> Enum.into(%{}), @fields)
  end
  def normalize(%Job{} = base, {job_name, opts}) when is_list(opts) do
    normalize(base, {job_name, opts |> Enum.into(%{})})
  end
  def normalize(%Job{} = base, {nil, opts}) when is_map(opts) do
    normalize_options(base, opts, @fields)
  end
  def normalize(%Job{} = base, {job_name, opts}) when is_map(opts) do
    opts = Map.put(opts, :name, job_name)

    normalize_options(base, opts, @fields)
  end
  def normalize(%Job{} = base, {schedule, task}) do
    normalize_options(base, %{schedule: schedule, task: task}, @fields)
  end

  @spec normalize_options(Job.t, map, [field]) :: Job.t | no_return
  defp normalize_options(job, %{name: name} = options, [:name | tail]) do
    normalize_options(Job.set_name(job, normalize_name(name)), options, tail)
  end
  defp normalize_options(job, options, [:name | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, %{schedule: schedule} = options, [:schedule | tail]) do
    normalize_options(Job.set_schedule(job, normalize_schedule(schedule)), options, tail)
  end
  defp normalize_options(job, options, [:schedule | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, %{task: task} = options, [:task | tail]) do
    normalize_options(Job.set_task(job, normalize_task(task)), options, tail)
  end
  defp normalize_options(job, options, [:task | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, %{run_strategy: run_strategy} = options, [:run_strategy | tail]) do
    normalize_options(Job.set_run_strategy(job, normalize_run_strategy(run_strategy)), options, tail)
  end
  defp normalize_options(job, options, [:run_strategy | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, %{overlap: overlap} = options, [:overlap | tail]) do
    normalize_options(Job.set_overlap(job, overlap), options, tail)
  end
  defp normalize_options(job, options, [:overlap | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, %{timezone: timezone} = options, [:timezone | tail]) when is_binary(timezone) do
    normalize_options(Job.set_timezone(job, timezone), options, tail)
  end
  defp normalize_options(job, %{timezone: :utc} = options, [:timezone | tail]) do
    normalize_options(Job.set_timezone(job, :utc), options, tail)
  end
  defp normalize_options(job, options, [:timezone | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, _, []), do: job

  @spec normalize_task(config_task) :: Job.task | no_return
  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task(fun) when is_function(fun, 0), do: fun
  defp normalize_task(fun) when is_function(fun), do: raise "Only 0 arity functions are supported via the short syntax."

  @doc false
  @spec normalize_schedule(config_schedule) :: Job.schedule | no_return
  def normalize_schedule(nil), do: nil
  def normalize_schedule(%CronExpression{} = e), do: e
  def normalize_schedule(e) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  def normalize_schedule({:cron, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  def normalize_schedule({:extended, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!(true)

  @spec normalize_name(atom | String.t) :: atom
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)
  defp normalize_name(name) when is_atom(name), do: name

  @spec normalize_run_strategy({module, any}) :: NodeList
  defp normalize_run_strategy({strategy, options}) when is_atom(strategy) do
    strategy.normalize_config!(options)
  end
end
