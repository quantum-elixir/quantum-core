defmodule Quantum.ExecutorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Quantum.{Executor, Executor.StartOpts, Job, NodeSelectorBroadcaster.Event}
  alias Quantum.TaskRegistry
  alias Quantum.TaskRegistry.StartOpts, as: TaskRegistryStartOpts

  doctest Executor

  defmodule TestScheduler do
    @moduledoc false

    use Quantum, otp_app: :job_broadcaster_test
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
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
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
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
        )

        assert_receive :executed
      end)
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
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
        )

        Executor.start_link(
          %StartOpts{
            task_supervisor_reference: task_supervisor,
            task_registry_reference: task_registry,
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
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
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
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
            debug_logging: debug_logging
          },
          %Event{job: job, node: Node.self()}
        )

        Process.sleep(150)
      end)

      assert :marked_running = TaskRegistry.mark_running(task_registry, job.name, Node.self())
    end

    test "logs error", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> raise "failed" end)
        |> Job.set_overlap(false)

      logs =
        capture_log(fn ->
          {:ok, task} =
            Executor.start_link(
              %StartOpts{
                task_supervisor_reference: task_supervisor,
                task_registry_reference: task_registry,
                debug_logging: debug_logging
              },
              %Event{job: job, node: Node.self()}
            )

          assert :ok == wait_for_termination(task)
        end)

      assert logs =~ ~r/\(RuntimeError\) failed/
    end

    test "logs exit", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> exit(:failure) end)
        |> Job.set_overlap(false)

      logs =
        capture_log(fn ->
          {:ok, task} =
            Executor.start_link(
              %StartOpts{
                task_supervisor_reference: task_supervisor,
                task_registry_reference: task_registry,
                debug_logging: debug_logging
              },
              %Event{job: job, node: Node.self()}
            )

          assert :ok == wait_for_termination(task)
        end)

      assert logs =~ ~r/\(exit\) :failure/
    end

    test "logs throw", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      ref = make_ref()

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> throw(ref) end)
        |> Job.set_overlap(false)

      logs =
        capture_log(fn ->
          {:ok, task} =
            Executor.start_link(
              %StartOpts{
                task_supervisor_reference: task_supervisor,
                task_registry_reference: task_registry,
                debug_logging: debug_logging
              },
              %Event{job: job, node: Node.self()}
            )

          assert :ok == wait_for_termination(task)
        end)

      assert logs =~ "(throw) #{inspect(ref)}"
    end
  end

  def send(caller) do
    send(caller, :executed)
  end

  def wait_for_termination(pid, timeout \\ 5000) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _pid, _reason} ->
        :ok
    after
      timeout ->
        :error
    end
  end
end
