defmodule Quantum.ExecutorSupervisor do
  @moduledoc """
  This `ConsumerSupervisor` is responsible to start a job for every execute event.
  """

  use ConsumerSupervisor

  alias Quantum.Util

  @spec start_link(GenServer.server(), GenServer.server(), GenServer.server(), GenServer.server()) ::
          GenServer.on_start()
  def start_link(name, execution_broadcaster, task_supervisor, task_registry) do
    __MODULE__
    |> ConsumerSupervisor.start_link(
      {execution_broadcaster, task_supervisor, task_registry},
      name: name
    )
    |> Util.start_or_link()
  end

  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: Remove when gen_stage:0.12 support is dropped
  if Util.gen_stage_v12?() do
    def init({execution_broadcaster, task_supervisor, task_registry}) do
      ConsumerSupervisor.init(
        {Quantum.Executor, {task_supervisor, task_registry}},
        strategy: :one_for_one,
        subscribe_to: [{execution_broadcaster, max_demand: 50}]
      )
    end
  else
    def init({execution_broadcaster, task_supervisor, task_registry}) do
      ConsumerSupervisor.init(
        [{Quantum.Executor, {task_supervisor, task_registry}}],
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
          GenServer.server()
        }) :: Supervisor.child_spec()
  def child_spec({name, execution_broadcaster, task_supervisor, task_registry}) do
    %{
      super([])
      | start: {
          __MODULE__,
          :start_link,
          [name, execution_broadcaster, task_supervisor, task_registry]
        }
    }
  end
end
