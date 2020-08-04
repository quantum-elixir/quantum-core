defmodule Quantum.NodeSelectorBroadcaster do
  @moduledoc false

  # Receives Added / Removed Jobs, Broadcasts Executions of Jobs

  use GenStage

  require Logger

  alias Quantum.ExecutionBroadcaster.Event, as: ExecuteEvent
  alias Quantum.Job
  alias Quantum.RunStrategy.NodeList

  alias __MODULE__.{Event, InitOpts, StartOpts, State}

  @type event :: {:add, Job.t()} | {:execute, Job.t()}

  # Start Stage
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    __MODULE__
    |> GenStage.start_link(
      struct!(
        InitOpts,
        Map.take(opts, [
          :execution_broadcaster_reference,
          :task_supervisor_reference
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

  @impl GenStage
  def init(%InitOpts{
        execution_broadcaster_reference: execution_broadcaster,
        task_supervisor_reference: task_supervisor_reference
      }) do
    {:producer_consumer,
     %State{
       task_supervisor_reference: task_supervisor_reference
     }, subscribe_to: [execution_broadcaster]}
  end

  @impl GenStage
  def handle_events(events, _, %{task_supervisor_reference: task_supervisor_reference} = state) do
    {:noreply,
     Enum.flat_map(events, fn %ExecuteEvent{job: job} ->
       job
       |> select_nodes(task_supervisor_reference)
       |> Enum.map(fn node ->
         %Event{job: job, node: node}
       end)
     end), state}
  end

  @impl GenStage
  def handle_info(_message, state) do
    {:noreply, [], state}
  end

  defp select_nodes(%Job{run_strategy: run_strategy} = job, task_supervisor) do
    run_strategy
    |> NodeList.nodes(job)
    |> Enum.filter(&check_node(&1, task_supervisor, job))
  end

  @spec check_node(Node.t(), GenServer.server(), Job.t()) :: boolean
  defp check_node(node, task_supervisor, %{name: job_name}) do
    if running_node?(node, task_supervisor) do
      true
    else
      Logger.warn(
        "Node #{inspect(node)} is not running. Job #{inspect(job_name)} could not be executed."
      )

      false
    end
  end

  # Check if the task supervisor runs on a given node
  @spec running_node?(Node.t(), GenServer.server()) :: boolean
  defp running_node?(node, _) when node == node(), do: true

  defp running_node?(node, task_supervisor) do
    node
    |> :rpc.call(:erlang, :whereis, [task_supervisor])
    |> is_pid()
  end
end
