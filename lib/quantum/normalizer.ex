defmodule Quantum.Normalizer do

  @moduledoc false

  alias Quantum.Job

  @fields [:name,
           :schedule,
           :task,
           :overlap,
           :nodes]

  # Creates named Quantum.Job
  # Input:
  # [
  #   newsletter: [
  #     schedule: "* * * * *",
  #     task: {MyModule, :my_method, [1, 2, 3]},
  #   ]
  # ]
  # Output:
  # %Quantum.Job{
  #   name: :newsletter,
  #   schedule: "* * * * *",
  #   task: {MyModule, :my_method, [1, 2, 3]},
  # }
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

  # Creates unnamed Quantum.Job
  # Input:
  # "* * * * *": {MyModule, :my_method, []}
  # Output:
  # %Quantum.Job{
  #   name: nil,
  #   schedule: "* * * * *",
  #   task: {MyModule, :my_method, []},
  #   args: []
  # }
  def normalize(base, j) do
    {schedule, task} = normalize_unnamed_job(j)
    normalize(base, {nil, %{schedule: schedule, task: task}})
  end

  # Converts a job {expr, fun} into its canonical format.
  # Cron expression is converted to lowercase string and
  # day and month names are translated to their indexes.
  defp normalize_unnamed_job({e, fun}) do
    schedule = normalize_schedule(e)
    case normalize_task(fun) do
      {mod, fun, args} -> {schedule, {mod, fun, args}}
      fun -> {schedule, fun}
    end
  end

  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task(fun) when is_function(fun, 0), do: fun
  defp normalize_task(fun) when is_function(fun), do: raise "Only 0 arity functions are supported via the short syntax."

  defp normalize_schedule(e = %Crontab.CronExpression{}), do: e
  defp normalize_schedule(e) when is_binary(e), do: e |> String.downcase |> Crontab.CronExpression.Parser.parse!
  defp normalize_schedule({:cron, e}) when is_binary(e), do: e |> String.downcase |> Crontab.CronExpression.Parser.parse!
  defp normalize_schedule({:extended, e}) when is_binary(e), do: e |> String.downcase |> Crontab.CronExpression.Parser.parse!(true)

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(string) when is_binary(string), do: String.to_atom(string)
  defp atomize(atom) when is_atom(atom), do: atom

  # defp job_opts(job_name, opts) do
  #   job_opts(job_name, opts)
  #
  #   %{
  #     name: job_name,
  #     schedule: extract(:schedule, opts),
  #     task: extract(:task, opts),
  #     overlap: extract(:overlap, opts, overlap),
  #     nodes: :nodes |> extract(opts, default_nodes()) |> atomize
  #   }
  # end

  defp normalize_options(job, options = %{name: name}, [:name | tail]) do
    normalize_options(Job.set_name(job, name), options, tail)
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
    normalize_options(Job.set_nodes(job, atomize(nodes)), options, tail)
  end
  defp normalize_options(job, options, [:nodes | tail]) do
    normalize_options(job, options, tail)
  end

  defp normalize_options(job, _, []), do: job
end
