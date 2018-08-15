defmodule Quantum.ExecutorSupervisor do
  @moduledoc """
  This `ConsumerSupervisor` is responsible to start a job for every execute event.
  """

  use ConsumerSupervisor

  alias Quantum.Executor.StartOpts, as: ExecutorStartOpts
  alias Quantum.Util

  alias __MODULE__.{InitOpts, StartOpts}

  @spec start_link(
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          boolean()
        ) :: GenServer.on_start()
  def start_link(name, execution_broadcaster, task_supervisor, task_registry, debug_logging),
    do:
      start_link(%StartOpts{
        name: name,
        execution_broadcaster_reference: execution_broadcaster,
        task_supervisor_reference: task_supervisor,
        task_registry_reference: task_registry,
        cluster_task_supervisor_registry_reference: nil,
        debug_logging: debug_logging
      })

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

  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: Remove when gen_stage:0.12 support is dropped
  if Util.gen_stage_v12?() do
    def init(
          %InitOpts{
            execution_broadcaster: execution_broadcaster
          } = opts
        ) do
      ConsumerSupervisor.init(
        {Quantum.Executor,
         Map.take(opts, [
           :task_supervisor_reference,
           :task_registry_reference,
           :debug_logging,
           :cluster_task_supervisor_registry_reference
         ])},
        strategy: :one_for_one,
        subscribe_to: [{execution_broadcaster, max_demand: 50}]
      )
    end
  else
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
  end

  @doc false
  @spec child_spec({
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          boolean()
        }) :: Supervisor.child_spec()
  def child_spec({name, execution_broadcaster, task_supervisor, task_registry, debug_logging}),
    do:
      child_spec(%StartOpts{
        name: name,
        execution_broadcaster_reference: execution_broadcaster,
        task_supervisor_reference: task_supervisor,
        task_registry_reference: task_registry,
        cluster_task_supervisor_registry_reference: nil,
        debug_logging: debug_logging
      })

  @spec child_spec(StartOpts.t()) :: Supervisor.child_spec()
  def child_spec(%StartOpts{} = opts), do: super(opts)
end
