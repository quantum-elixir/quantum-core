defmodule Quantum.Executor do
  @moduledoc """
  Task to actually execute a Task
  """

  use Task

  require Logger

  alias Quantum.{
    ClusterTaskSupervisorRegistry,
    ExecutionBroadcaster.Event,
    Job,
    RunStrategy.NodeList,
    TaskRegistry
  }

  alias __MODULE__.StartOpts

  @doc """
  Start the Task

  ### Arguments

    * `task_supervisor` - The supervisor that runs the task
    * `task_registry` - The registry that knows if a task is already running
    * `message` - The Message to Execute (`%Event{job: %Job{}}`)

  """
  @spec start_link(StartOpts.t(), Event.t()) :: {:ok, pid}
  def start_link(opts, %Event{job: job}) do
    Task.start_link(fn ->
      execute(opts, job)
    end)
  end

  @spec execute(
          StartOpts.t(),
          Job.t()
        ) :: :ok
  # Execute task on all given nodes without checking for overlap
  defp execute(
         %StartOpts{
           task_supervisor_reference: task_supervisor,
           task_registry_reference: _task_registry,
           debug_logging: debug_logging,
           cluster_task_supervisor_registry_reference: cluster_task_supervisor_registry
         },
         %Job{overlap: true, run_strategy: run_strategy} = job
       ) do
    # Find Nodes to run on
    # Check if Node is up and running
    # Run Task
    job
    |> nodes(run_strategy, task_supervisor, cluster_task_supervisor_registry)
    |> Enum.each(&run(&1, job, task_supervisor, debug_logging))

    :ok
  end

  # Execute task on all given nodes with checking for overlap
  defp execute(
         %StartOpts{
           task_supervisor_reference: task_supervisor,
           task_registry_reference: task_registry,
           debug_logging: debug_logging,
           cluster_task_supervisor_registry_reference: cluster_task_supervisor_registry
         },
         %Job{overlap: false, run_strategy: run_strategy, name: job_name} = job
       ) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Start execution of job #{inspect(job_name)}"
      end)

    # Find Nodes to run on
    # Mark Running and only continue with item if it worked
    # Check if Node is up and running
    # Run Task
    # Mark Task as finished
    job
    |> nodes(run_strategy, task_supervisor, cluster_task_supervisor_registry)
    |> Enum.filter(&(TaskRegistry.mark_running(task_registry, job_name, &1) == :marked_running))
    |> Enum.map(&run(&1, job, task_supervisor, debug_logging))
    |> Enum.each(fn {node, %Task{ref: ref}} ->
      receive do
        {^ref, _} ->
          TaskRegistry.mark_finished(task_registry, job_name, node)

        {:DOWN, ^ref, _, _, _} ->
          TaskRegistry.mark_finished(task_registry, job_name, node)
      end
    end)

    :ok
  end

  defp nodes(job, run_strategy, task_supervisor, nil) do
    run_strategy
    |> NodeList.nodes(job)
    |> Enum.filter(&check_node(&1, task_supervisor, job))
  end

  defp nodes(job, run_strategy, task_supervisor, cluster_task_supervisor_registry) do
    available_nodes = ClusterTaskSupervisorRegistry.nodes(cluster_task_supervisor_registry)
    NodeList.nodes(run_strategy, job, available_nodes)
  rescue
    UndefinedFunctionError ->
      nodes(job, run_strategy, task_supervisor, nil)
  end

  # Ececute the given function on a given node via the task supervisor
  @spec run(Node.t(), Job.t(), GenServer.server(), boolean()) :: {Node.t(), Task.t()}
  defp run(node, %{name: job_name, task: task}, task_supervisor, debug_logging) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Task for job #{inspect(job_name)} started on node #{
          inspect(node)
        }"
      end)

    {
      node,
      Task.Supervisor.async_nolink({task_supervisor, node}, fn ->
        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Execute started for job #{inspect(job_name)}"
          end)

        result = execute_task(task)

        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Execution ended for job #{inspect(job_name)}, which yielded result: #{
              inspect(result)
            }"
          end)

        :ok
      end)
    }
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

  # Run function
  @spec execute_task(Quantum.Job.task()) :: any
  defp execute_task({mod, fun, args}) do
    :erlang.apply(mod, fun, args)
  end

  defp execute_task(fun) when is_function(fun, 0) do
    fun.()
  end
end
