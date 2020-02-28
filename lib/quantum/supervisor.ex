defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor

  require Logger

  alias Quantum.{Job, Normalizer}

  # Starts the quantum supervisor.
  @spec start_link(GenServer.server(), atom, Keyword.t()) :: GenServer.on_start()
  def start_link(quantum, otp_app, opts) do
    name = Keyword.take(opts, [:name])
    Supervisor.start_link(__MODULE__, {quantum, otp_app, opts}, name)
  end

  @impl Supervisor
  def init({scheduler, otp_app, opts}) do
    opts = runtime_config(scheduler, otp_app, opts)
    opts = quantum_init(scheduler, opts)
    %{storage: storage, scheduler: ^scheduler} = opts = Map.new(opts)

    storage_opts =
      opts
      |> Map.get(:storage_opts, [])
      |> Keyword.put(:scheduler, scheduler)

    task_registry_opts = %Quantum.TaskRegistry.StartOpts{
      name: Module.concat(scheduler, TaskRegistry)
    }

    clock_broadcaster_opts =
      struct!(
        Quantum.ClockBroadcaster.StartOpts,
        opts
        |> Map.take([:debug_logging, :storage, :scheduler])
        |> Map.merge(%{
          name: Module.concat(scheduler, ClockBroadcaster),
          start_time: NaiveDateTime.utc_now()
        })
      )

    job_broadcaster_opts =
      struct!(
        Quantum.JobBroadcaster.StartOpts,
        opts
        |> Map.take([:jobs, :storage, :scheduler, :debug_logging])
        |> Map.merge(%{
          name: Module.concat(scheduler, JobBroadcaster)
        })
      )

    execution_broadcaster_opts =
      struct!(
        Quantum.ExecutionBroadcaster.StartOpts,
        opts
        |> Map.take([
          :storage,
          :scheduler,
          :debug_logging
        ])
        |> Map.merge(%{
          job_broadcaster_reference: Module.concat(scheduler, JobBroadcaster),
          clock_broadcaster_reference: Module.concat(scheduler, ClockBroadcaster),
          name: Module.concat(scheduler, ExecutionBroadcaster)
        })
      )

    node_selector_broadcaster_opts = %Quantum.NodeSelectorBroadcaster.StartOpts{
      execution_broadcaster_reference: Module.concat(scheduler, ExecutionBroadcaster),
      task_supervisor_reference: Module.concat(scheduler, TaskSupervisor),
      name: Module.concat(scheduler, NodeSelectorBroadcaster)
    }

    executor_supervisor_opts =
      struct!(
        Quantum.ExecutorSupervisor.StartOpts,
        opts
        |> Map.take([:debug_logging])
        |> Map.merge(%{
          node_selector_broadcaster_reference: Module.concat(scheduler, NodeSelectorBroadcaster),
          task_supervisor_reference: Module.concat(scheduler, TaskSupervisor),
          task_registry_reference: Module.concat(scheduler, TaskRegistry),
          name: Module.concat(scheduler, ExecutorSupervisor)
        })
      )

    Supervisor.init(
      [
        {Task.Supervisor, [name: Module.concat(scheduler, TaskSupervisor)]},
        {storage, storage_opts ++ [name: Module.concat(scheduler, Storage)]},
        {Quantum.ClockBroadcaster, clock_broadcaster_opts},
        {Quantum.TaskRegistry, task_registry_opts},
        {Quantum.JobBroadcaster, job_broadcaster_opts},
        {Quantum.ExecutionBroadcaster, execution_broadcaster_opts},
        {Quantum.NodeSelectorBroadcaster, node_selector_broadcaster_opts},
        {Quantum.ExecutorSupervisor, executor_supervisor_opts}
      ],
      strategy: :rest_for_one
    )
  end

  # Run Optional Callback in Quantum Scheduler Implementation
  @spec quantum_init(atom, Keyword.t()) :: Keyword.t()
  defp quantum_init(quantum, config) do
    if Code.ensure_loaded?(quantum) and function_exported?(quantum, :init, 1) do
      quantum.init(config)
    else
      config
    end
  end

  defp runtime_config(quantum, otp_app, custom) do
    config = Quantum.scheduler_config(quantum, otp_app, custom)

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
