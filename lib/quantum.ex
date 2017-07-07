defmodule Quantum do
  @moduledoc """
  Contains config functions to aid the rest of the lib
  """

  require Logger

  alias Quantum.Normalizer
  alias Quantum.Job
  alias Quantum.RunStrategy.Random

  @defaults [global: false,
             cron: [],
             timeout: 5_000,
             schedule: nil,
             overlap: true,
             timezone: :utc,
             run_strategy: {Random, :cluster}]

  @doc """
  Retrieves only scheduler related configuration.
  """
  def scheduler_config(quantum, otp_app, custom) do
    config =
      @defaults
      |> Keyword.merge(Application.get_env(otp_app, quantum, []))
      |> Keyword.merge(custom)
      |> Keyword.merge([otp_app: otp_app, quantum: quantum])

    # Default Runner Name
    runner = if Keyword.fetch!(config, :global),
      do: {:global, Module.concat(quantum, Runner)},
      else: Module.concat(quantum, Runner)

    # Default Task Supervisor Name
    task_supervisor = Module.concat(quantum, Task.Supervisor)

    config
    |> Keyword.put_new(:runner, runner)
    |> Keyword.put_new(:task_supervisor, task_supervisor)
  end

  @doc """
  Retrieves the comprehensive runtime configuration.
  """
  def runtime_config(quantum, otp_app, custom) do
    config = scheduler_config(quantum, otp_app, custom)

    # Load Jobs from Config
    jobs =
      config
      |> Keyword.get(:jobs, [])
      |> Enum.map(&Normalizer.normalize(quantum.new_job(config), &1))
      |> remove_jobs_with_duplicate_names(quantum)

    Keyword.put(config, :jobs, jobs)
  end

  defp remove_jobs_with_duplicate_names(job_list, quantum) do
    Enum.reduce(job_list, [], fn
      %Job{name: nil} = job, acc ->
        [{nil, job} | acc]
      %Job{name: name} = job, acc ->
        if Enum.member?(Keyword.keys(acc), name) do
          Logger.warn("Job with name '#{name}' of quantum '#{quantum}' not started due to duplicate job name")
          acc
        else
          [{name, job} | acc]
        end
    end)
  end
end
