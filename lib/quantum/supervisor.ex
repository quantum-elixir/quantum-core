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

    Supervisor.init(
      [
        {Task.Supervisor, [name: Keyword.get(opts, :task_supervisor)]},
        {Quantum.ClusterTaskSupervisorRegistry,
         task_supervisor: Keyword.get(opts, :task_supervisor),
         name: Keyword.get(opts, :cluster_task_supervisor_registry)},
        {
          Quantum.TaskRegistry,
          Keyword.fetch!(opts, :task_registry_opts)
        },
        {
          Quantum.ClockBroadcaster,
          Keyword.fetch!(opts, :clock_broadcaster_opts) ++
            opts ++
            [
              # TODO: Load from Storage
              start_time: NaiveDateTime.utc_now()
            ]
        },
        {
          Quantum.JobBroadcaster,
          {
            Keyword.fetch!(opts, :job_broadcaster_opts),
            Keyword.fetch!(opts, :jobs),
            Keyword.fetch!(opts, :storage),
            Keyword.fetch!(opts, :quantum),
            Keyword.fetch!(opts, :debug_logging)
          }
        },
        {
          Quantum.ExecutionBroadcaster,
          Keyword.fetch!(opts, :execution_broadcaster_opts) ++ opts
        },
        {
          Quantum.ExecutorSupervisor,
          {
            Keyword.fetch!(opts, :executor_supervisor),
            Keyword.fetch!(opts, :execution_broadcaster),
            Keyword.fetch!(opts, :task_supervisor),
            Keyword.fetch!(opts, :task_registry),
            Keyword.get(opts, :cluster_task_supervisor_registry),
            Keyword.fetch!(opts, :debug_logging)
          }
        }
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
