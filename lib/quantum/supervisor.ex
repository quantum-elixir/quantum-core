defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor

  # Starts the quantum supervisor.
  @spec start_link(GenServer.server(), Keyword.t()) :: GenServer.on_start()
  def start_link(quantum, opts) do
    name = Keyword.take(opts, [:name])
    Supervisor.start_link(__MODULE__, {quantum, opts}, name)
  end

  @impl Supervisor
  def init({scheduler, opts}) do
    %{
      storage: storage,
      scheduler: ^scheduler,
      task_supervisor_name: task_supervisor_name,
      storage_name: storage_name,
      task_registry_name: task_registry_name,
      clock_broadcaster_name: clock_broadcaster_name,
      job_broadcaster_name: job_broadcaster_name,
      execution_broadcaster_name: execution_broadcaster_name,
      node_selector_broadcaster_name: node_selector_broadcaster_name,
      executor_supervisor_name: executor_supervisor_name
    } =
      opts =
      opts
      |> scheduler.config
      |> quantum_init(scheduler)
      |> Map.new()

    task_supervisor_opts = [name: task_supervisor_name]

    storage_opts =
      opts
      |> Map.get(:storage_opts, [])
      |> Keyword.put(:scheduler, scheduler)
      |> Keyword.put(:name, storage_name)

    task_registry_opts = %Quantum.TaskRegistry.StartOpts{name: task_registry_name}

    clock_broadcaster_opts =
      struct!(
        Quantum.ClockBroadcaster.StartOpts,
        opts
        |> Map.take([:debug_logging, :storage, :scheduler])
        |> Map.put(:name, clock_broadcaster_name)
        |> Map.put(:start_time, NaiveDateTime.utc_now())
      )

    job_broadcaster_opts =
      struct!(
        Quantum.JobBroadcaster.StartOpts,
        opts
        |> Map.take([:jobs, :storage, :scheduler, :debug_logging])
        |> Map.put(:name, job_broadcaster_name)
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
        |> Map.put(:job_broadcaster_reference, job_broadcaster_name)
        |> Map.put(:clock_broadcaster_reference, clock_broadcaster_name)
        |> Map.put(:name, execution_broadcaster_name)
      )

    node_selector_broadcaster_opts = %Quantum.NodeSelectorBroadcaster.StartOpts{
      execution_broadcaster_reference: execution_broadcaster_name,
      task_supervisor_reference: task_supervisor_name,
      name: node_selector_broadcaster_name
    }

    executor_supervisor_opts =
      struct!(
        Quantum.ExecutorSupervisor.StartOpts,
        opts
        |> Map.take([:debug_logging])
        |> Map.put(:node_selector_broadcaster_reference, node_selector_broadcaster_name)
        |> Map.put(:task_supervisor_reference, task_supervisor_name)
        |> Map.put(:task_registry_reference, task_registry_name)
        |> Map.put(:name, executor_supervisor_name)
        |> Map.put(:scheduler, scheduler)
      )

    Supervisor.init(
      [
        {Task.Supervisor, task_supervisor_opts},
        {storage, storage_opts},
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
  @spec quantum_init(Keyword.t(), atom) :: Keyword.t()
  defp quantum_init(config, scheduler) do
    scheduler.init(config)
  end
end
