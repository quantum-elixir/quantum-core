defmodule Quantum.Normalizer do

  @moduledoc false

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
  defp normalize_job({job_name, opts}) when opts |> is_list do
    %Quantum.Job{
      name: job_name,
      schedule: extract(:schedule, opts),
      task: extract(:task, opts),
      args: extract(:args, opts, [])
    }
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
    {schedule, task} = normalize_unnamed_job(j)
    %Quantum.Job{
      # name: :__unnamed__,
      schedule: schedule,
      task: task
    }
  end

  # Converts a job {expr, fun} into its canonical format.
  # Cron expression is converted to lowercase string and
  # day and month names are translated to their indexes.
  defp normalize_unnamed_job({e, fun}), do: {normalize_schedule(e), normalize_task(fun)}

  # Converts a string representation of schedule+job into
  # its canonical format.
  # Input: "* * * * * MyApp.MyModule.my_method"
  # Output: {"* * * * *", {"MyApp.MyModule", "my_method"}}
  defp normalize_unnamed_job(e) do
  	[[_, schedule, task]] = Regex.scan(~r/^(\S+\s+\S+\s+\S+\s+\S+\s+\S+|@\w+)\s+(.*\.\w+)$/, e)
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
  defp normalize_task({mod, fun}), do: {mod, fun}
  defp normalize_task(fun), do: fun

  defp normalize_schedule(e) when e |> is_atom, do: normalize_schedule e |> Atom.to_string
  defp normalize_schedule(e), do: e |> String.downcase |> Quantum.Translator.translate

  # Extracts given option from options list of named task
  defp extract(name, opts, d \\ nil)
  defp extract(:schedule, opts, d), do: Keyword.get(opts, :schedule, d) |> normalize_schedule
  defp extract(:task, opts, d), do: Keyword.get(opts, :task, d) |> normalize_task
  defp extract(name, opts, d), do: Keyword.get(opts, name, d)

end
