defmodule Quantum.ExecutorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Quantum.{ExecutionBroadcaster.Event, Executor, Executor.StartOpts, Job}
  alias Quantum.RunStrategy.All
  alias Quantum.TaskRegistry
  alias Quantum.TaskRegistry.StartOpts, as: TaskRegistryStartOpts

  doctest Executor

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :job_broadcaster_test
  end

  setup do
    {:ok, _task_supervisor} =
      start_supervised({Task.Supervisor, [name: Module.concat(__MODULE__, TaskSupervisor)]})

    {:ok, task_registry} =
      start_supervised(
        {TaskRegistry, %TaskRegistryStartOpts{name: Module.concat(__MODULE__, TaskRegistry)}}
      )

    {
      :ok,
      %{
        task_supervisor: Module.concat(__MODULE__, TaskSupervisor),
        task_registry: task_registry,
        debug_logging: true
      }
    }
  end

  describe "start_link/3" do
    test "executes given task using anonymous function", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> send(caller, :executed) end)

      capture_log(fn ->
        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        assert_receive :executed
      end)
    end

    test "executes given task using function tuple", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()

      job =
        TestScheduler.new_job()
        |> Job.set_task({__MODULE__, :send, [caller]})

      capture_log(fn ->
        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        assert_receive :executed
      end)
    end

    test "doesn't crash on invalid node", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()
      node = :"invalid-name@invalid-host"

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> send(caller, :executed) end)
        |> Job.set_run_strategy(%All{nodes: [node]})

      assert capture_log(fn ->
               Executor.start_link(
                 %StartOpts{
                   task_supervisor_reference: task_supervisor,
                   task_registry_reference: task_registry,
                   debug_logging: debug_logging,
                   cluster_task_supervisor_registry_reference: nil
                 },
                 %Event{job: job}
               )

               refute_receive :executed
             end) =~
               "Node #{inspect(node)} is not running. Job #{inspect(job.name)} could not be executed."
    end

    test "executes given task without overlap", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn ->
          Process.sleep(50)
          send(caller, :executed)
        end)
        |> Job.set_overlap(false)

      capture_log(fn ->
        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        assert_receive :executed
        refute_receive :executed
      end)
    end

    test "releases lock on success", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn ->
          Process.sleep(50)
          send(caller, :executed)
        end)
        |> Job.set_overlap(false)

      capture_log(fn ->
        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        # Wait until running
        Process.sleep(25)

        assert :already_running = TaskRegistry.mark_running(task_registry, job.name, Node.self())

        assert_receive :executed
        refute_receive :executed

        assert :marked_running = TaskRegistry.mark_running(task_registry, job.name, Node.self())
      end)
    end

    test "releases lock on error", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> raise "failed" end)
        |> Job.set_overlap(false)

      # Mute Error
      capture_log(fn ->
        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging,
            cluster_task_supervisor_registry_reference: nil
          },
          %Event{job: job}
        )

        Process.sleep(150)
      end)

      assert :marked_running = TaskRegistry.mark_running(task_registry, job.name, Node.self())
    end
  end

  def send(caller) do
    send(caller, :executed)
  end
end
