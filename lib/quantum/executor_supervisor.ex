defmodule Quantum.ExecutorSupervisor do
  @moduledoc """
  This `ConsumerSupervisor` is responsible to start a job for every execute event.
  """

  use ConsumerSupervisor

  alias Quantum.Util

  @spec start_link(
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          GenServer.server(),
          boolean()
        ) :: GenServer.on_start()
  def start_link(name, execution_broadcaster, task_supervisor, task_registry, debug_logging) do
    ConsumerSupervisor.start_link(
      __MODULE__,
      %{
        execution_broadcaster: execution_broadcaster,
        task_supervisor: task_supervisor,
        task_registry: task_registry,
        cluster_task_supervisor_registry: nil,
        debug_logging: debug_logging
      },
      name: name
    )
  end

  @spec start_link(%{
          name: GenServer.server(),
          execution_broadcaster: GenServer.server(),
          task_supervisor: GenServer.server(),
          task_registry: GenServer.server(),
          cluster_task_supervisor_registry: nil | GenServer.server(),
          debug_logging: boolean()
        }) :: GenServer.on_start()
  def start_link(opts) do
    ConsumerSupervisor.start_link(
      __MODULE__,
      Map.take(opts, [
        :execution_broadcaster,
        :task_supervisor,
        :task_registry,
        :cluster_task_supervisor_registry,
        :debug_logging
      ]),
      name: Map.fetch!(opts, :name)
    )
  end

  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: Remove when gen_stage:0.12 support is dropped
  if Util.gen_stage_v12?() do
    def init(
          %{
            execution_broadcaster: execution_broadcaster
          } = opts
        ) do
      ConsumerSupervisor.init(
        {Quantum.Executor,
         Map.take(opts, [
           :task_supervisor,
           :task_registry,
           :debug_logging,
           :cluster_task_supervisor_registry
         ])},
        strategy: :one_for_one,
        subscribe_to: [{execution_broadcaster, max_demand: 50}]
      )
    end
  else
    def init(
          %{
            execution_broadcaster: execution_broadcaster
          } = opts
        ) do
      ConsumerSupervisor.init(
        [
          {Quantum.Executor,
           Map.take(opts, [
             :task_supervisor,
             :task_registry,
             :debug_logging,
             :cluster_task_supervisor_registry
           ])}
        ],
        strategy: :one_for_one,
        subscribe_to: [{execution_broadcaster, max_demand: 50}]
      )
    end
  end

  @doc false
  @spec child_spec(
          {
            GenServer.server(),
            GenServer.server(),
            GenServer.server(),
            GenServer.server(),
            boolean()
          }
          | {
              GenServer.server(),
              GenServer.server(),
              GenServer.server(),
              GenServer.server(),
              GenServer.server(),
              boolean()
            }
        ) :: Supervisor.child_spec()
  def child_spec({name, execution_broadcaster, task_supervisor, task_registry, debug_logging}),
    do:
      child_spec(
        {name, execution_broadcaster, task_supervisor, task_registry, nil, debug_logging}
      )

  def child_spec(
        {name, execution_broadcaster, task_supervisor, task_registry,
         cluster_task_supervisor_registry, debug_logging}
      ) do
    %{
      super([])
      | start: {
          __MODULE__,
          :start_link,
          [
            %{
              name: name,
              execution_broadcaster: execution_broadcaster,
              task_supervisor: task_supervisor,
              task_registry: task_registry,
              cluster_task_supervisor_registry: cluster_task_supervisor_registry,
              debug_logging: debug_logging
            }
          ]
        }
    }
  end
end
