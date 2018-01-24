defmodule Quantum.Executor do
  @moduledoc """
  Task to actually execute a Task

  """

  use Task

  require Logger

  alias Quantum.{Job, TaskRegistry}
  alias Quantum.RunStrategy.NodeList

  @doc """
  Start the Task

  ### Arguments

    * `task_supervisor` - The supervisor that runs the task
    * `task_registry` - The registry that knows if a task is already running
    * `message` - The Message to Execute (`{:execute, %Job{}}`)

  """
  @spec start_link({GenServer.server(), GenServer.server()}, {:execute, Job.t()}) :: {:ok, pid}
  def start_link({task_supervisor, task_registry}, {:execute, job}) do
    Task.start_link(fn ->
      execute(task_supervisor, task_registry, job)
    end)
  end

  @spec execute(GenServer.server(), GenServer.server(), Job.t()) :: :ok
  # Execute task on all given nodes without checking for overlap
  defp execute(task_supervisor, _task_registry, %Job{overlap: true} = job) do
    # Find Nodes to run on
    # Check if Node is up and running
    # Run Task
    job.run_strategy
    |> NodeList.nodes(job)
    |> Enum.filter(&check_node(&1, task_supervisor, job))
    |> Enum.each(&run(&1, job, task_supervisor))

    :ok
  end

  # Execute task on all given nodes with checking for overlap
  defp execute(task_supervisor, task_registry, %Job{overlap: false} = job) do
    Logger.debug(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Start execution of job #{inspect(job.name)}"
    end)

    # Find Nodes to run on
    # Mark Running and only continue with item if it worked
    # Check if Node is up and running
    # Run Task
    # Mark Task as finished
    job.run_strategy
    |> NodeList.nodes(job)
    |> Enum.filter(&(TaskRegistry.mark_running(task_registry, job.name, &1) == :marked_running))
    |> Enum.filter(&check_node(&1, task_supervisor, job))
    |> Enum.map(&run(&1, job, task_supervisor))
    |> Enum.each(fn {node, %Task{ref: ref}} ->
         receive do
           {^ref, _} ->
             TaskRegistry.mark_finished(task_registry, job.name, node)

           {:DOWN, ^ref, _, _, _} ->
             TaskRegistry.mark_finished(task_registry, job.name, node)
         end
       end)

    :ok
  end

  # Ececute the given function on a given node via the task supervisor
  @spec run(Node.t(), Job.t(), GenServer.server()) :: {Node.t(), Task.t()}
  defp run(node, job, task_supervisor) do
    Logger.debug(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Task for job #{inspect(job.name)} started on node #{inspect(node)}"
    end)

    {
      node,
      Task.Supervisor.async_nolink({task_supervisor, node}, fn ->
        Logger.debug(fn ->
          "[#{inspect(Node.self())}][#{__MODULE__}] Execute started for job #{inspect(job.name)}"
        end)

        result = execute_task(job.task)

        Logger.debug(fn ->
          "[#{inspect(Node.self())}][#{__MODULE__}] Execution ended for job #{inspect(job.name)}, which yielded result: #{inspect(result)}"
        end)

        :ok
      end)
    }
  end

  @spec check_node(Node.t(), GenServer.server(), Job.t()) :: boolean
  defp check_node(node, task_supervisor, job) do
    if running_node?(node, task_supervisor) do
      true
    else
      Logger.warn(
        "Node #{inspect(node)} is not running. Job #{inspect(job.name)} could not be executed."
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
