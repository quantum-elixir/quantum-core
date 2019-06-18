defmodule Quantum do
  @moduledoc """
  Contains config functions to aid the rest of the lib
  """

  require Logger

  alias Quantum.{Job, Normalizer, RunStrategy.Random, Storage.Noop}

  @defaults [
    global: false,
    cron: [],
    timeout: 5_000,
    schedule: nil,
    overlap: true,
    timezone: :utc,
    run_strategy: {Random, :cluster},
    debug_logging: true
  ]

  @doc """
  Retrieves only scheduler related configuration.
  """
  def scheduler_config(quantum, otp_app, custom) do
    config =
      @defaults
      |> Keyword.merge(Application.get_env(otp_app, quantum, []))
      |> Keyword.merge(custom)
      |> Keyword.merge(otp_app: otp_app, quantum: quantum)

    global = Keyword.fetch!(config, :global)

    job_broadcaster_name = Module.concat(quantum, JobBroadcaster)

    job_broadcaster_reference =
      if global,
        do: {:via, :swarm, job_broadcaster_name},
        else: job_broadcaster_name

    execution_broadcaster_name = Module.concat(quantum, ExecutionBroadcaster)

    execution_broadcaster_reference =
      if global,
        do: {:via, :swarm, execution_broadcaster_name},
        else: execution_broadcaster_name

    executor_supervisor_name = Module.concat(quantum, ExecutorSupervisor)
    executor_supervisor_reference = executor_supervisor_name

    task_registry_name = Module.concat(quantum, TaskRegistry)

    task_registry_reference =
      if global,
        do: {:via, :swarm, task_registry_name},
        else: task_registry_name

    cluster_task_supervisor_registry_name =
      if global,
        do: Module.concat(quantum, ClusterTaskSupervisorRegistry),
        else: nil

    cluster_task_supervisor_registry_reference = cluster_task_supervisor_registry_name

    task_supervisor_name = Module.concat(quantum, Task.Supervisor)
    task_supervisor_reference = task_supervisor_name

    config
    |> Keyword.put_new(:quantum, quantum)
    |> Keyword.put_new(:scheduler, quantum)
    |> update_in([:schedule], &Normalizer.normalize_schedule/1)
    |> Keyword.put_new(:job_broadcaster_name, job_broadcaster_name)
    |> Keyword.put_new(:job_broadcaster_reference, job_broadcaster_reference)
    |> Keyword.put_new(:execution_broadcaster_name, execution_broadcaster_name)
    |> Keyword.put_new(:execution_broadcaster_reference, execution_broadcaster_reference)
    |> Keyword.put_new(:executor_supervisor_name, executor_supervisor_name)
    |> Keyword.put_new(:executor_supervisor_reference, executor_supervisor_reference)
    |> Keyword.put_new(:task_registry_name, task_registry_name)
    |> Keyword.put_new(:task_registry_reference, task_registry_reference)
    |> Keyword.put_new(:task_supervisor_name, task_supervisor_name)
    |> Keyword.put_new(:task_supervisor_reference, task_supervisor_reference)
    |> Keyword.put_new(
      :cluster_task_supervisor_registry_name,
      cluster_task_supervisor_registry_name
    )
    |> Keyword.put_new(
      :cluster_task_supervisor_registry_reference,
      cluster_task_supervisor_registry_reference
    )
    |> Keyword.put_new(:storage, Noop)
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
        Logger.warn(
          "Job with name '#{name}' of quantum '#{quantum}' not started due to duplicate job name"
        )

        acc
      else
        Map.put_new(acc, name, job)
      end
    end)
    |> Map.values()
  end
end
