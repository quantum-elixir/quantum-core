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

    # Default Job Broadcaster Name
    job_broadcaster = if Keyword.fetch!(config, :global),
      do: {:global, Module.concat(quantum, JobBroadcaster)},
      else: Module.concat(quantum, JobBroadcaster)

    execution_broadcaster = if Keyword.fetch!(config, :global),
      do: {:global, Module.concat(quantum, ExecutionBroadcaster)},
      else: Module.concat(quantum, ExecutionBroadcaster)

    executor_supervisor = if Keyword.fetch!(config, :global),
      do: {:global, Module.concat(quantum, ExecutorSupervisor)},
      else: Module.concat(quantum, ExecutorSupervisor)

    task_registry = if Keyword.fetch!(config, :global),
      do: {:global, Module.concat(quantum, TaskRegistry)},
      else: Module.concat(quantum, TaskRegistry)

    # Default Task Supervisor Name
    task_supervisor = Module.concat(quantum, Task.Supervisor)

    config
    |> Keyword.put_new(:job_broadcaster, job_broadcaster)
    |> Keyword.put_new(:execution_broadcaster, execution_broadcaster)
    |> Keyword.put_new(:executor_supervisor, executor_supervisor)
    |> Keyword.put_new(:task_registry, task_registry)
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
    job_list
    |> Enum.reduce(%{}, fn %Job{name: name} = job, acc ->
      if Enum.member?(Map.keys(acc), name) do
        Logger.warn("Job with name '#{name}' of quantum '#{quantum}' not started due to duplicate job name")
        acc
      else
        Map.put_new(acc, name, job)
      end
    end)
    |> Map.values
  end
end
