defmodule Quantum.ExecutorSupervisor do
  @moduledoc """
  This `ConsumerSupervisor` is responsible to start a job for every execute event.
  """

  use ConsumerSupervisor

  alias Quantum.Executor.StartOpts, as: ExecutorStartOpts

  alias __MODULE__.{InitOpts, StartOpts}

  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    ConsumerSupervisor.start_link(
      __MODULE__,
      struct!(
        InitOpts,
        Map.take(opts, [
          :execution_broadcaster_reference,
          :task_supervisor_reference,
          :task_registry_reference,
          :cluster_task_supervisor_registry_reference,
          :debug_logging
        ])
      ),
      name: name
    )
  end

  def init(
        %InitOpts{
          execution_broadcaster_reference: execution_broadcaster
        } = opts
      ) do
    executor_opts =
      struct!(
        ExecutorStartOpts,
        Map.take(opts, [
          :task_supervisor_reference,
          :task_registry_reference,
          :debug_logging,
          :cluster_task_supervisor_registry_reference
        ])
      )

    ConsumerSupervisor.init(
      [{Quantum.Executor, executor_opts}],
      strategy: :one_for_one,
      subscribe_to: [{execution_broadcaster, max_demand: 50}]
    )
  end

  @spec child_spec(StartOpts.t()) :: Supervisor.child_spec()
  def child_spec(%StartOpts{} = opts), do: super(opts)
end
