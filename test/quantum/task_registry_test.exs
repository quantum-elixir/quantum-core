defmodule Quantum.TaskRegistryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.TaskRegistry

  doctest TaskRegistry,
    except: [mark_running: 3, mark_finished: 3, is_running?: 2, any_running?: 1]

  setup do
    {:ok, registry} = start_supervised({TaskRegistry, __MODULE__})

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
end
