defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor

  alias Quantum.ClusterTaskSupervisorRegistry

  alias Quantum.ClusterTaskSupervisorRegistry.StartOpts,
    as: ClusterTaskSupervisorRegistryStartOpts

  alias Quantum.ClockBroadcaster
  alias Quantum.ClockBroadcaster.StartOpts, as: ClockBroadcasterStartOpts
  alias Quantum.ExecutionBroadcaster
  alias Quantum.ExecutionBroadcaster.StartOpts, as: ExecutionBroadcasterStartOpts
  alias Quantum.ExecutorSupervisor
  alias Quantum.ExecutorSupervisor.StartOpts, as: ExecutorSupervisorStartOpts
  alias Quantum.JobBroadcaster
  alias Quantum.JobBroadcaster.StartOpts, as: JobBroadcasterStartOpts
  alias Quantum.TaskRegistry
  alias Quantum.TaskRegistry.StartOpts, as: TaskRegistryStartOpts

  @doc """
  Starts the quantum supervisor.
  """
  @spec start_link(GenServer.server(), atom, Keyword.t()) :: GenServer.on_start()
  def start_link(quantum, otp_app, opts) do
    name = Keyword.take(opts, [:name])
    Supervisor.start_link(__MODULE__, {quantum, otp_app, opts}, name)
  end

  ## Callbacks

  def init({quantum, otp_app, opts}) do
    opts = Quantum.runtime_config(quantum, otp_app, opts)
    opts = quantum_init(quantum, opts)
    opts = Enum.into(opts, %{})

    %{
      task_registry_name: task_registry_name,
      clock_broadcaster_name: clock_broadcaster_name,
      job_broadcaster_name: job_broadcaster_name,
      execution_broadcaster_name: execution_broadcaster_name,
      cluster_task_supervisor_registry_name: cluster_task_supervisor_registry_name,
      task_supervisor_name: task_supervisor_name,
      executor_supervisor_name: executor_supervisor_name,
      global: global
    } = opts

    task_registry_opts = %TaskRegistryStartOpts{name: task_registry_name}

    clock_broadcaster_opts =
      struct!(
        ClockBroadcasterStartOpts,
        opts
        |> Map.take([:debug_logging])
        |> Map.put(:name, clock_broadcaster_name)
        # TODO: Load from Storage
        |> Map.put(:start_time, NaiveDateTime.utc_now())
      )

    job_broadcaster_opts =
      struct!(
        JobBroadcasterStartOpts,
        opts
        |> Map.take([:jobs, :storage, :scheduler, :debug_logging])
        |> Map.put(:name, job_broadcaster_name)
      )

    cluster_task_supervisor_registry_opts =
      struct!(
        ClusterTaskSupervisorRegistryStartOpts,
        opts
        |> Map.take([:task_supervisor_reference])
        |> Map.put(:name, cluster_task_supervisor_registry_name)
      )

    execution_broadcaster_opts =
      struct!(
        ExecutionBroadcasterStartOpts,
        opts
        |> Map.take([
          :job_broadcaster_reference,
          :clock_broadcaster_reference,
          :storage,
          :scheduler,
          :debug_logging
        ])
        |> Map.put(:name, execution_broadcaster_name)
      )

    executor_supervisor_opts =
      struct!(
        ExecutorSupervisorStartOpts,
        opts
        |> Map.take([
          :execution_broadcaster_reference,
          :task_supervisor_reference,
          :task_registry_reference,
          :cluster_task_supervisor_registry_reference,
          :debug_logging
        ])
        |> Map.put(:name, executor_supervisor_name)
      )

    workers =
      if global do
        %{start: {TaskRegistry, f, a}} = TaskRegistry.child_spec(task_registry_opts)
        Swarm.register_name(task_registry_name, TaskRegistry, f, a, 15_000)

        %{start: {ClockBroadcaster, f, a}} = ClockBroadcaster.child_spec(clock_broadcaster_opts)
        Swarm.register_name(clock_broadcaster_name, ClockBroadcaster, f, a)

        %{start: {JobBroadcaster, f, a}} = JobBroadcaster.child_spec(job_broadcaster_opts)
        Swarm.register_name(job_broadcaster_name, JobBroadcaster, f, a)

        %{start: {ExecutionBroadcaster, f, a}} =
          ExecutionBroadcaster.child_spec(execution_broadcaster_opts)

        Swarm.register_name(execution_broadcaster_name, ExecutionBroadcaster, f, a)

        [
          {Task.Supervisor, [name: task_supervisor_name]},
          {ClusterTaskSupervisorRegistry, cluster_task_supervisor_registry_opts},
          {ExecutorSupervisor, executor_supervisor_opts}
        ]
      else
        [
          {Task.Supervisor, [name: task_supervisor_name]},
          {ClusterTaskSupervisorRegistry, cluster_task_supervisor_registry_opts},
          {ClockBroadcaster, clock_broadcaster_opts},
          {TaskRegistry, task_registry_opts},
          {JobBroadcaster, job_broadcaster_opts},
          {ExecutionBroadcaster, execution_broadcaster_opts},
          {ExecutorSupervisor, executor_supervisor_opts}
        ]
      end

    Supervisor.init(
      workers,
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
end
