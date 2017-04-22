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
           :nodes]

  @type config_short_notation :: {config_schedule, config_task}
  # TODO: remove any and fix dialyzer
  @type config_full_notation :: {config_name | nil, Keyword.t | struct | any}

  @typep field :: :name | :schedule | :task | :overlap | :nodes
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
  def normalize(base, job)
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
  defp normalize_options(job, options = %{name: name}, [:name | tail]) do
    normalize_options(Job.set_name(job, normalize_name(name)), options, tail)
  end
  defp normalize_options(job, options, [:name | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, options = %{schedule: schedule}, [:schedule | tail]) do
    normalize_options(Job.set_schedule(job, normalize_schedule(schedule)), options, tail)
  end
  defp normalize_options(job, options, [:schedule | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, options = %{task: task}, [:task | tail]) do
    normalize_options(Job.set_task(job, normalize_task(task)), options, tail)
  end
  defp normalize_options(job, options, [:task | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, options = %{overlap: overlap}, [:overlap | tail]) do
    normalize_options(Job.set_overlap(job, overlap), options, tail)
  end
  defp normalize_options(job, options, [:overlap | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, options = %{nodes: nodes}, [:nodes | tail]) do
    normalize_options(Job.set_nodes(job, normalize_nodes(nodes)), options, tail)
  end
  defp normalize_options(job, options, [:nodes | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, _, []), do: job

  @spec normalize_task(config_task) :: Job.task
  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task(fun) when is_function(fun, 0), do: fun
  defp normalize_task(fun) when is_function(fun), do: raise "Only 0 arity functions are supported via the short syntax."

  @spec normalize_schedule(config_schedule) :: Job.schedule
  defp normalize_schedule(e = %Crontab.CronExpression{}), do: e
  defp normalize_schedule(e) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  defp normalize_schedule({:cron, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!
  defp normalize_schedule({:extended, e}) when is_binary(e), do: e |> String.downcase |> CronExpressionParser.parse!(true)

  @spec normalize_nodes([Node.t | String.t]) :: Job.nodes
  defp normalize_nodes(list) when is_list(list), do: Enum.map(list, &normalize_node/1)

  @spec normalize_node(atom | String.t) :: Node.t
  defp normalize_node(node) when is_binary(node), do: String.to_atom(node)
  defp normalize_node(node) when is_atom(node), do: node

  @spec normalize_name(atom | String.t) :: atom
  defp normalize_name(name) when is_binary(name), do: String.to_atom(name)
  defp normalize_name(name) when is_atom(name), do: name
end
