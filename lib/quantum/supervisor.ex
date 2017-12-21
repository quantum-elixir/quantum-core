defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor
  alias Quantum.TaskStagesSupervisor

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
        {TaskStagesSupervisor, opts},
        {Task.Supervisor, [name: Keyword.get(opts, :task_supervisor)]}
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
