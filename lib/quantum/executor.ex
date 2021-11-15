defmodule Quantum.Executor do
  @moduledoc false

  # Task to actually execute a Task

  use Task

  require Logger

  alias Quantum.{
    Job,
    NodeSelectorBroadcaster.Event,
    TaskRegistry
  }

  alias __MODULE__.StartOpts

  @spec start_link(StartOpts.t(), Event.t()) :: {:ok, pid}
  def start_link(opts, %Event{job: job, node: node}) do
    Task.start_link(fn ->
      execute(opts, job, node)
    end)
  end

  @spec execute(StartOpts.t(), Job.t(), Node.t()) :: :ok
  # Execute task on all given nodes without checking for overlap
  defp execute(
         %StartOpts{
           task_supervisor_reference: task_supervisor,
           debug_logging: debug_logging,
           scheduler: scheduler
         },
         %Job{overlap: true} = job,
         node
       ) do
    run(node, job, task_supervisor, debug_logging, scheduler)

    :ok
  end

  # Execute task on all given nodes with checking for overlap
  defp execute(
         %StartOpts{
           task_supervisor_reference: task_supervisor,
           task_registry_reference: task_registry,
           debug_logging: debug_logging,
           scheduler: scheduler
         },
         %Job{overlap: false, name: job_name} = job,
         node
       ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Start execution of job", node: Node.self(), name: job_name}
      end)

    case TaskRegistry.mark_running(task_registry, job_name, node) do
      :marked_running ->
        %Task{ref: ref} = run(node, job, task_supervisor, debug_logging, scheduler)

        receive do
          {^ref, _} ->
            TaskRegistry.mark_finished(task_registry, job_name, node)

          {:DOWN, ^ref, _, _, _} ->
            TaskRegistry.mark_finished(task_registry, job_name, node)

            :ok
        end

      _ ->
        :ok
    end
  end

  # Ececute the given function on a given node via the task supervisor
  @spec run(Node.t(), Job.t(), GenServer.server(), boolean(), atom()) :: Task.t()
  defp run(
         node,
         %Job{name: job_name, task: task} = job,
         task_supervisor,
         debug_logging,
         scheduler
       ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Task for job started on node", node: Node.self(), name: job_name, started_on: node}
      end)

    Task.Supervisor.async_nolink({task_supervisor, node}, fn ->
      debug_logging &&
        Logger.debug(fn ->
          {"Execute started for job", node: Node.self(), name: job_name}
        end)

      try do
        :telemetry.span([:quantum, :job], %{job: job, node: node, scheduler: scheduler}, fn ->
          result = execute_task(task)
          {result, %{job: job, node: node, scheduler: scheduler, result: result}}
        end)
      catch
        type, value ->
          debug_logging &&
            Logger.debug(fn ->
              {
                "Execution failed for job",
                node: Node.self(), name: job_name, type: type, value: value
              }
            end)

          log_exception(type, value, __STACKTRACE__)
      else
        result ->
          debug_logging &&
            Logger.debug(fn ->
              {"Execution ended for job", node: Node.self(), name: job_name, result: result}
            end)
      end

      :ok
    end)
  end

  # Run function
  @spec execute_task(Quantum.Job.task()) :: any
  defp execute_task({mod, fun, args}) do
    :erlang.apply(mod, fun, args)
  end

  defp execute_task(fun) when is_function(fun, 0) do
    fun.()
  end

  def log_exception(kind, reason, stacktrace) do
    reason = Exception.normalize(kind, reason, stacktrace)

    # TODO: Remove in a future version and make elixir 1.10 minimum requirement
    if Version.match?(System.version(), "< 1.10.0") do
      Logger.error(Exception.format(kind, reason, stacktrace))
    else
      crash_reason =
        case kind do
          :throw -> {{:nocatch, reason}, stacktrace}
          _ -> {reason, stacktrace}
        end

      Logger.error(
        Exception.format(kind, reason, stacktrace),
        crash_reason: crash_reason
      )
    end
  end
end
