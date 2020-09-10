defmodule Quantum.TaskRegistryTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.TaskRegistry
  alias Quantum.TaskRegistry.StartOpts

  doctest TaskRegistry,
    except: [mark_running: 3, mark_finished: 3]

  setup do
    {:ok, _registry} = start_supervised({TaskRegistry, %StartOpts{name: __MODULE__}})

    {:ok, %{registry: __MODULE__}}
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
end
