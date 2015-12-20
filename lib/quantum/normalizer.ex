defmodule Quantum.Normalizer do

  @moduledoc false

  alias Quantum.Translator

  def normalize(j) do
    nj = normalize_job(j)
    {nj.name, nj}
  end

  # Creates named Quantum.Job
  # Input:
  # [
  #   newsletter: [
  #     schedule: "* * * * *",
  #     task: "MyModule.my_method",
  #     args: [1, 2, 3]
  #   ]
  # ]
  # Output:
  # %Quantum.Job{
  #   name: :newsletter,
  #   schedule: "* * * * *",
  #   task: {"MyModule", "my_method"},
  #   args: [1, 2, 3]
  # }
  defp normalize_job({job_name, %Quantum.Job{} = job}) do
    # Sets defauts for job if necessary
    job_name |> job_opts([]) |> Map.merge(%{job | name: job_name })
  end

  defp normalize_job({job_name, opts}) when opts |> is_list or opts |> is_map do
    %Quantum.Job{} |> Map.merge(job_opts(job_name, opts))
  end

  # Creates unnamed Quantum.Job
  # Input:
  # "* * * * * MyModule.my_method"
  # OR
  # "* * * * *": {MyModule, "my_method"}
  # OR
  # "* * * * *": &MyModule.my_method/0
  # Output:
  # %Quantum.Job{
  #   name: :__unnamed__,
  #   schedule: "* * * * *",
  #   task: {"MyModule", "my_method"} / &MyModule.my_method/0,
  #   args: []
  # }
  defp normalize_job(j) do
    opts = case normalize_unnamed_job(j) do
      {schedule, task, args} -> %{schedule: schedule, task: task, args: args}
      {schedule, task} -> %{schedule: schedule, task: task}
    end
    normalize_job({nil, opts})
  end

  # Converts a job {expr, fun} into its canonical format.
  # Cron expression is converted to lowercase string and
  # day and month names are translated to their indexes.
  defp normalize_unnamed_job({e, fun}) do
    schedule = normalize_schedule(e)
    case normalize_task(fun) do
      {mod, fun, args} -> {schedule, {mod, fun}, args}
      fun -> {schedule, fun}
    end
  end

  # Converts a string representation of schedule+job into
  # its canonical format.
  # Input: "* * * * * MyApp.MyModule.my_method"
  # Output: {"* * * * *", {"MyApp.MyModule", "my_method"}}
  defp normalize_unnamed_job(e) do
    [[_, schedule, task]] =
      ~r/^(\S+\s+\S+\s+\S+\s+\S+\s+\S+|@\w+)\s+(.*\.\w+)$/
      |> Regex.scan(e)
    {normalize_schedule(schedule), normalize_task(task)}
  end

  # Converts string representation of task into its
  # canonical format
  # Input: "MyApp.MyModule.my_method"
  # Output: {"MyApp.MyModule", "my_method"}
  defp normalize_task(t) when t |> is_binary do
    [[_, mod, fun]] = Regex.scan(~r/^(.*)\.(\w+)$/, t)
    {mod, fun}
  end
  defp normalize_task({mod, fun, args}), do: {mod, fun, args}
  defp normalize_task({mod, fun}), do: {mod, fun}
  defp normalize_task(fun), do: fun

  defp normalize_schedule(e) when e |> is_atom, do: normalize_schedule e |> Atom.to_string
  defp normalize_schedule(e), do: e |> String.downcase |> Translator.translate

  # Extracts given option from options list of named task
  defp extract(name, opts, d \\ nil)
  defp extract(name, opts, d) when opts |> is_list, do: extract(name, opts |> Enum.into(%{}), d)
  defp extract(:schedule, opts, d), do: opts |> Map.get(:schedule, d) |> normalize_schedule
  defp extract(:task, opts, d), do: opts |> Map.get(:task, d) |> normalize_task
  defp extract(name, opts, d), do: opts |> Map.get(name, d)

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(string) when is_binary(string), do: String.to_atom(string)
  defp atomize(atom) when is_atom(atom), do: atom

  defp job_opts(job_name, opts) do
    %{
      name: job_name,
      schedule: extract(:schedule, opts),
      task: extract(:task, opts),
      args: extract(:args, opts, []),
      nodes: :nodes |> extract(opts, [node()]) |> atomize
    }
  end

end
