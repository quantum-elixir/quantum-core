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

  defmodule TelemetryTestHandler do
    require Logger

    def handle_event(
          [:quantum, :job, :start],
          %{system_time: _system_time} = _measurements,
          %{job_name: job_name, module: _module, node: _node} = _metadata,
          %{parent_thread: parent_thread, test_id: test_id}
        ) do
      send(parent_thread, %{test_id: test_id, job_name: job_name, type: :start})
    end

    def handle_event(
          [:quantum, :job, :stop],
          %{duration: _duration} = _measurements,
          %{job_name: job_name, module: _module, node: _node} = _metadata,
          %{parent_thread: parent_thread, test_id: test_id}
        ) do
      send(parent_thread, %{test_id: test_id, job_name: job_name, type: :stop})
    end

    def handle_event(
          [:quantum, :job, :exception],
          %{duration: _duration} = _measurements,
          %{
            job_name: job_name,
            module: _module,
            node: _node,
            reason: reason,
            stacktrace: stacktrace
          } = _metadata,
          %{parent_thread: parent_thread, test_id: test_id}
        ) do
      send(parent_thread, %{
        test_id: test_id,
        job_name: job_name,
        type: :exception,
        reason: reason,
        stacktrace: stacktrace
      })
    end
  end

  defp attach_telemetry(test_id, parent_thread) do
    :telemetry.attach_many(
      test_id,
      [
        [:quantum, :job, :start],
        [:quantum, :job, :stop],
        [:quantum, :job, :exception]
      ],
      &TelemetryTestHandler.handle_event/4,
      %{
        parent_thread: parent_thread,
        test_id: test_id
      }
    )
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

      test_id = "log-anonymous-job-handler"

      :ok = attach_telemetry(test_id, self())

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

        assert_receive %{test_id: ^test_id, type: :start}
        assert_receive %{test_id: ^test_id, type: :stop}, 2000
      end)
    end

    test "executes given task using function tuple", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()

      test_id = "log-function-tuple-job-handler"

      :ok = attach_telemetry(test_id, self())

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

      assert_receive %{test_id: ^test_id, type: :start}
      assert_receive %{test_id: ^test_id, type: :stop}, 2000
    end

    test "executes given task without overlap", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()
      test_id = "log-task-no-overlap-handler"

      :ok = attach_telemetry(test_id, self())

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

      assert_receive %{test_id: ^test_id, type: :start}
      assert_receive %{test_id: ^test_id, type: :stop}, 2000
    end

    test "releases lock on success", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      caller = self()
      test_id = "release-lock-on-success-handler"

      :ok = attach_telemetry(test_id, self())

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

      assert_receive %{test_id: ^test_id, type: :start}
      assert_receive %{test_id: ^test_id, type: :stop}, 2000
    end

    test "releases lock on error", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      test_id = "release-lock-on-error-handler"

      :ok = attach_telemetry(test_id, self())

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
      assert_receive %{test_id: ^test_id, type: :start}

      assert_receive %{
                       test_id: ^test_id,
                       type: :exception,
                       reason: %RuntimeError{message: "failed"},
                       stacktrace: [
                         {Quantum.ExecutorTest, _, _, _},
                         {Quantum.Executor, _, _, _},
                         {Task.Supervised, _, _, _},
                         {Task.Supervised, _, _, _},
                         {:proc_lib, _, _, _}
                       ]
                     },
                     2000
    end

    test "logs error", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      test_id = "logs-error-handler"

      :ok = attach_telemetry(test_id, self())

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
      assert_receive %{test_id: ^test_id, type: :start}

      assert_receive %{
                       test_id: ^test_id,
                       type: :exception,
                       reason: %RuntimeError{message: "failed"},
                       stacktrace: [
                         {Quantum.ExecutorTest, _, _, _},
                         {Quantum.Executor, _, _, _},
                         {Task.Supervised, _, _, _},
                         {Task.Supervised, _, _, _},
                         {:proc_lib, _, _, _}
                       ]
                     },
                     2000
    end

    test "logs exit", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      test_id = "logs-exit-handler"

      :ok = attach_telemetry(test_id, self())

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
      assert_receive %{test_id: ^test_id, type: :start}

      assert_receive %{
                       test_id: ^test_id,
                       type: :exception,
                       reason: :failure,
                       stacktrace: [
                         {Quantum.ExecutorTest, _, _, _},
                         {Quantum.Executor, _, _, _},
                         {Task.Supervised, _, _, _},
                         {Task.Supervised, _, _, _},
                         {:proc_lib, _, _, _}
                       ]
                     },
                     2000
    end

    test "logs throw", %{
      task_supervisor: task_supervisor,
      task_registry: task_registry,
      debug_logging: debug_logging
    } do
      test_id = "logs-throw-handler"

      :ok = attach_telemetry(test_id, self())

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
      assert_receive %{test_id: ^test_id, type: :start}

      assert_receive %{
                       test_id: ^test_id,
                       type: :exception,
                       reason: ^ref,
                       stacktrace: [
                         {Quantum.ExecutorTest, _, _, _},
                         {Quantum.Executor, _, _, _},
                         {Task.Supervised, _, _, _},
                         {Task.Supervised, _, _, _},
                         {:proc_lib, _, _, _}
                       ]
                     },
                     2000
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
