defmodule Quantum.ExecutorSupervisor do
  @moduledoc false

  # This `ConsumerSupervisor` is responsible to start a job for every execute event.

  use ConsumerSupervisor

  alias Quantum.Executor.StartOpts, as: ExecutorStartOpts

  alias __MODULE__.{InitOpts, StartOpts}

  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    __MODULE__
    |> ConsumerSupervisor.start_link(
      struct!(
        InitOpts,
        Map.take(opts, [
          :node_selector_broadcaster_reference,
          :task_supervisor_reference,
          :task_registry_reference,
          :debug_logging,
          :scheduler
        ])
      ),
      name: name
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.monitor(pid)
        {:ok, pid}

      {:error, _reason} = error ->
        error
    end
  end

  @impl ConsumerSupervisor
  def init(
        %InitOpts{
          node_selector_broadcaster_reference: node_selector_broadcaster
        } = opts
      ) do
    executor_opts =
      struct!(
        ExecutorStartOpts,
        Map.take(opts, [
          :task_supervisor_reference,
          :task_registry_reference,
          :debug_logging,
          :scheduler
        ])
      )

    ConsumerSupervisor.init(
      [{Quantum.Executor, executor_opts}],
      strategy: :one_for_one,
      subscribe_to: [{node_selector_broadcaster, max_demand: 50}]
    )
  end
end
