defmodule Quantum.Supervisor do
  @moduledoc false

  use Supervisor

  @doc """
  Starts the quantum supervisor.
  """
  def start_link(quantum, otp_app, opts) do
    name = Keyword.take(opts, [:name])
    Supervisor.start_link(__MODULE__, {quantum, otp_app, opts}, name)
  end

  ## Callbacks

  def init({quantum, otp_app, opts}) do
    opts = Quantum.runtime_config(quantum, otp_app, opts)
    opts = quantum_init(quantum, opts)

    children = [
      supervisor(Task.Supervisor, [[name: Keyword.get(opts, :task_supervisor)]]),
      worker(Quantum.Runner, [opts], restart: :permanent)
    ]

    supervise(children, strategy: :one_for_one)
  end

  # Run Optional Callback in Quantum Scheduler Implementation
  defp quantum_init(quantum, config) do
    if Code.ensure_loaded?(quantum) and function_exported?(quantum, :init, 1) do
      quantum.init(config)
    else
      config
    end
  end
end
