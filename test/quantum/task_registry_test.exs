defmodule Quantum.TaskRegistryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.{HandoffHelper, TaskRegistry}
  alias Quantum.TaskRegistry.StartOpts

  doctest TaskRegistry,
    except: [mark_running: 3, mark_finished: 3, is_running?: 2, any_running?: 1]

  setup do
    {:ok, registry} = start_supervised({TaskRegistry, %StartOpts{name: __MODULE__}})

    {:ok, %{registry: registry}}
  end

  describe "running" do
    test "not running => running", %{registry: registry} do
      task = make_ref()

      assert :marked_running = TaskRegistry.mark_running(registry, task, self())
    end

    test "running => already running", %{registry: registry} do
      task = make_ref()

      TaskRegistry.mark_running(registry, task, self())

      assert :already_running = TaskRegistry.mark_running(registry, task, self())
    end
  end

  describe "finished" do
    test "finish existing", %{registry: registry} do
      task = make_ref()

      TaskRegistry.mark_running(registry, task, self())

      assert :ok = TaskRegistry.mark_finished(registry, task, self())
    end

    test "finish not existing", %{registry: registry} do
      task = make_ref()

      assert :ok = TaskRegistry.mark_finished(registry, task, self())
    end
  end

  describe "is_running?" do
    test "not running", %{registry: registry} do
      task = make_ref()
      assert false == TaskRegistry.is_running?(registry, task)
    end

    test "running", %{registry: registry} do
      task = make_ref()

      TaskRegistry.mark_running(registry, task, self())

      assert true == TaskRegistry.is_running?(registry, task)
    end
  end

  describe "any_running?" do
    test "not running", %{registry: registry} do
      assert false == TaskRegistry.any_running?(registry)
    end

    test "running", %{registry: registry} do
      task = make_ref()

      TaskRegistry.mark_running(registry, task, self())

      assert true == TaskRegistry.any_running?(registry)
    end
  end

  describe "swarm/handoff" do
    test "works" do
      Process.flag(:trap_exit, true)

      %{start: {TaskRegistry, f, a}} =
        TaskRegistry.child_spec(%StartOpts{name: Module.concat(__MODULE__, Old)})

      {:ok, old_task_registry} = apply(TaskRegistry, f, a)

      %{start: {TaskRegistry, f, a}} =
        TaskRegistry.child_spec(%StartOpts{name: Module.concat(__MODULE__, New)})

      {:ok, new_task_registry} = apply(TaskRegistry, f, a)

      task_1 = make_ref()
      task_2 = make_ref()

      TaskRegistry.mark_running(old_task_registry, task_1, self())
      TaskRegistry.mark_running(new_task_registry, task_2, self())

      HandoffHelper.initiate_handoff(old_task_registry, new_task_registry)

      assert TaskRegistry.is_running?(new_task_registry, task_1)
      assert TaskRegistry.is_running?(new_task_registry, task_2)

      assert_receive {:EXIT, ^old_task_registry, :shutdown}
    end
  end

  describe "swarm/resolve_conflict" do
    test "works" do
      Process.flag(:trap_exit, true)

      %{start: {TaskRegistry, f, a}} =
        TaskRegistry.child_spec(%StartOpts{name: Module.concat(__MODULE__, Old)})

      {:ok, old_task_registry} = apply(TaskRegistry, f, a)

      %{start: {TaskRegistry, f, a}} =
        TaskRegistry.child_spec(%StartOpts{name: Module.concat(__MODULE__, New)})

      {:ok, new_task_registry} = apply(TaskRegistry, f, a)

      task_1 = make_ref()
      task_2 = make_ref()

      TaskRegistry.mark_running(old_task_registry, task_1, self())
      TaskRegistry.mark_running(new_task_registry, task_2, self())

      HandoffHelper.resolve_conflict(old_task_registry, new_task_registry)

      assert TaskRegistry.is_running?(new_task_registry, task_1)
      assert TaskRegistry.is_running?(new_task_registry, task_2)

      assert_receive {:EXIT, ^old_task_registry, :shutdown}
    end
  end
end
