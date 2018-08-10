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

    task_registry_opts = Keyword.fetch!(opts, :task_registry)
    task_registry_name = Keyword.fetch!(task_registry_opts, :name)

    job_broadcaster_opts = Keyword.fetch!(opts, :job_broadcaster)
    job_broadcaster_name = Keyword.fetch!(job_broadcaster_opts, :name)

    execution_broadcaster_opts = Keyword.fetch!(opts, :execution_broadcaster)
    execution_broadcaster_name = Keyword.fetch!(execution_broadcaster_opts, :name)

    Supervisor.init(
      [
        {Task.Supervisor, [name: Keyword.get(opts, :task_supervisor)]},
        {
          Quantum.TaskRegistry,
          task_registry_opts
        },
        {
          Quantum.JobBroadcaster,
          {
            job_broadcaster_opts,
            Keyword.fetch!(opts, :jobs),
            Keyword.fetch!(opts, :storage),
            Keyword.fetch!(opts, :quantum),
            Keyword.fetch!(opts, :debug_logging)
          }
        },
        {
          Quantum.ExecutionBroadcaster,
          {
            execution_broadcaster_opts,
            job_broadcaster_name,
            Keyword.fetch!(opts, :storage),
            Keyword.fetch!(opts, :quantum),
            Keyword.fetch!(opts, :debug_logging)
          }
        },
        {
          Quantum.ExecutorSupervisor,
          {
            Keyword.fetch!(opts, :executor_supervisor),
            execution_broadcaster_name,
            Keyword.fetch!(opts, :task_supervisor),
            task_registry_name,
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
