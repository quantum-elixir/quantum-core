defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor

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

    %{quantum: quantum} = opts

    task_registry_opts = %Quantum.TaskRegistry.StartOpts{
      name: Module.concat(quantum, TaskRegistry)
    }

    clock_broadcaster_opts =
      struct!(
        Quantum.ClockBroadcaster.StartOpts,
        opts
        |> Map.take([:debug_logging])
        |> Map.merge(%{
          name: Module.concat(quantum, ClockBroadcaster),
          # TODO: Load from Storage
          start_time: NaiveDateTime.utc_now()
        })
      )

    job_broadcaster_opts =
      struct!(
        Quantum.JobBroadcaster.StartOpts,
        opts
        |> Map.take([:jobs, :storage, :scheduler, :debug_logging])
        |> Map.merge(%{
          name: Module.concat(quantum, JobBroadcaster)
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
          job_broadcaster_reference: Module.concat(quantum, JobBroadcaster),
          clock_broadcaster_reference: Module.concat(quantum, ClockBroadcaster),
          name: Module.concat(quantum, ExecutionBroadcaster)
        })
      )

    executor_supervisor_opts =
      struct!(
        Quantum.ExecutorSupervisor.StartOpts,
        opts
        |> Map.take([:debug_logging])
        |> Map.merge(%{
          execution_broadcaster_reference: Module.concat(quantum, ExecutionBroadcaster),
          task_supervisor_reference: Module.concat(quantum, TaskSupervisor),
          task_registry_reference: Module.concat(quantum, TaskRegistry),
          name: Module.concat(quantum, ExecutorSupervisor)
        })
      )

    Supervisor.init(
      [
        {Task.Supervisor, [name: Module.concat(quantum, Task.Supervisor)]},
        {Quantum.ClockBroadcaster, clock_broadcaster_opts},
        {Quantum.TaskRegistry, task_registry_opts},
        {Quantum.JobBroadcaster, job_broadcaster_opts},
        {Quantum.ExecutionBroadcaster, execution_broadcaster_opts},
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
end
