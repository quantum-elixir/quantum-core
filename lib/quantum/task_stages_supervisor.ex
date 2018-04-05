defmodule Quantum.TaskStagesSupervisor do
  @moduledoc false

  use Supervisor

  alias Quantum.Util

  @doc """
  Starts the quantum supervisor.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    __MODULE__
    |> Supervisor.start_link(opts, name: Keyword.fetch!(opts, :task_stages_supervisor))
    |> Util.start_or_link()
  end

  ## Callbacks

  def child_spec(opts) do
    %{super([]) | start: {__MODULE__, :start_link, [opts]}}
  end

  def init(opts) do
    Supervisor.init(
      [
        {
          Quantum.TaskRegistry,
          Keyword.fetch!(opts, :task_registry)
        },
        {
          Quantum.JobBroadcaster,
          {
            Keyword.fetch!(opts, :job_broadcaster),
            Keyword.fetch!(opts, :jobs),
            Keyword.fetch!(opts, :storage),
            Keyword.fetch!(opts, :quantum),
            Keyword.fetch!(opts, :debug_logging)
          }
        },
        {
          Quantum.ExecutionBroadcaster,
          {
            Keyword.fetch!(opts, :execution_broadcaster),
            Keyword.fetch!(opts, :job_broadcaster),
            Keyword.fetch!(opts, :storage),
            Keyword.fetch!(opts, :quantum),
            Keyword.fetch!(opts, :debug_logging)
          }
        },
        {
          Quantum.ExecutorSupervisor,
          {
            Keyword.fetch!(opts, :executor_supervisor),
            Keyword.fetch!(opts, :execution_broadcaster),
            Keyword.fetch!(opts, :task_supervisor),
            Keyword.fetch!(opts, :task_registry),
            Keyword.fetch!(opts, :debug_logging)
          }
        }
      ],
      strategy: :rest_for_one
    )
  end
end
