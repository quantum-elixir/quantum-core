defmodule Quantum.Normalizer do
  @moduledoc """
  Normalize Config values into a `Quantum.Job`.
  """

  alias Quantum.Job
  alias Crontab.CronExpression.Parser, as: CronExpressionParser

  @fields [:name,
           :schedule,
           :task,
           :overlap,
           :run_strategy]

  @type config_short_notation :: {config_schedule, config_task}
  @type config_full_notation :: {config_name | nil, Keyword.t | struct}

  @typep field :: :name | :schedule | :task | :overlap
  @type config_schedule :: Crontab.CronExpression.t | String.t | {:cron, String.t} | {:extended, String.t}
  @type config_task :: {module, fun, [any]} | (() -> any)
  @type config_name :: String.t | atom

  @doc """
  Normalize Config Input into `Quantum.Job`.

  ### Parameters:

    * `base` - Empty `Quantum.Job`
    * `job` - The Job To Normalize

  """
  @spec normalize(Job.t, config_full_notation | config_short_notation) :: Quantum.Job.t
  def normalize(base, job) when is_list(job) do
    normalize(base, {Keyword.get(job, :name), job})
  end
  def normalize(base, {job_name, opts}) when is_list(opts) do
    opts = opts
    |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, key, value) end)
    normalize(base, {job_name, opts})
  end
  def normalize(base, {job_name, opts}) when is_map(opts) do
    opts = Map.put(opts, :name, job_name)

    base
    |> normalize_options(opts, @fields)
  end
  def normalize(base, {schedule, task}) do
    normalize(base, {nil, %{schedule: normalize_schedule(schedule), task: normalize_task(task)}})
  end

  @spec normalize_options(Quantum.Job.t, struct, [field]) :: Quantum.Job.t
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

  defp normalize_options(job, _, []), do: job

  @spec normalize_task(config_task) :: Job.task
  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task(fun) when is_function(fun, 0), do: fun
  defp normalize_task(fun) when is_function(fun), do: raise "Only 0 arity functions are supported via the short syntax."

  @doc false
  @spec normalize_schedule(config_schedule) :: Job.schedule
  def normalize_schedule(%Crontab.CronExpression{} = e), do: e
  def normalize_schedule(e) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  def normalize_schedule({:cron, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  def normalize_schedule({:extended, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!(true)

  @spec normalize_name(atom | String.t) :: atom
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)
  defp normalize_name(name) when is_atom(name), do: name

  @spec normalize_run_strategy({module, any}) :: Quantum.RunStrategy.NodeList
  defp normalize_run_strategy({strategy, options}) when is_atom(strategy) do
    strategy.normalize_config!(options)
  end
end
