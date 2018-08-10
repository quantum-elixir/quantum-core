defmodule Quantum do
  @moduledoc """
  Contains config functions to aid the rest of the lib
  """

  require Logger

  alias Quantum.Normalizer
  alias Quantum.Job
  alias Quantum.RunStrategy.Random
  alias Quantum.Storage.Noop

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

    # Default Job Broadcaster Name
    global = Keyword.fetch!(config, :global)
    job_broadcaster = cluster_worker_config(Module.concat(quantum, JobBroadcaster), global)

    execution_broadcaster =
      cluster_worker_config(Module.concat(quantum, ExecutionBroadcaster), global)

    executor_supervisor = Module.concat(quantum, ExecutorSupervisor)

    task_registry = cluster_worker_config(Module.concat(quantum, TaskRegistry), global)

    # Default Task Supervisor Name
    task_supervisor = Module.concat(quantum, Task.Supervisor)

    config
    |> Keyword.put_new(:quantum, quantum)
    |> update_in([:schedule], &Normalizer.normalize_schedule/1)
    |> Keyword.put_new(:job_broadcaster, job_broadcaster)
    |> Keyword.put_new(:execution_broadcaster, execution_broadcaster)
    |> Keyword.put_new(:executor_supervisor, executor_supervisor)
    |> Keyword.put_new(:task_registry, task_registry)
    |> Keyword.put_new(:task_supervisor, task_supervisor)
    |> Keyword.put_new(:storage, Noop)
  end

  defp cluster_worker_config(module, false), do: [name: module, restart: :permanent]

  defp cluster_worker_config(module, true),
    do: [name: {:via, :swarm, module}, restart: :temporary]

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
