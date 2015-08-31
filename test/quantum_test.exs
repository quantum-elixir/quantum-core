defmodule QuantumTest do
  use ExUnit.Case

  test "adding a job at run time" do
    spec = "1 * * * *"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: spec, task: fun}
    assert Enum.member? Quantum.jobs, {nil, job}
  end

  test "adding a named job at run time" do
    name = "test_job"
    spec = "1 * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{schedule: spec, task: fun}
    :ok = Quantum.add_job(name, job)
    assert Enum.member? Quantum.jobs, {name, %{job | name: name}}
  end

  test "adding a unnamed job at run time" do
    spec = "1 * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{schedule: spec, task: fun}
    :ok = Quantum.add_job(job)
    assert Enum.member? Quantum.jobs, {nil, job}
  end

  test "adding a job at run time with atom expression" do
    spec = :"@daily"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: Atom.to_string(spec), task: fun}
    assert Enum.member? Quantum.jobs, {nil, job}
  end

  test "adding a job at run time with uppercase string" do
    spec = "@HOURLY"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: String.downcase(spec), task: fun}
    assert Enum.member? Quantum.jobs, {nil, job}
  end

  test "finding a named job" do
    name = :newsletter
    spec = "* * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{schedule: spec, task: fun}
    :ok = Quantum.add_job(name, job)
    fjob = Quantum.find_job(name)
    assert fjob.name == name
    assert fjob.schedule == spec
  end

  test "deactivating a named job" do
    name = :newsletter
    spec = "* * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{name: name, schedule: spec, task: fun}
    :ok = Quantum.add_job(name, job)
    :ok = Quantum.deactivate_job(name)
    sjob = Quantum.find_job(name)
    assert sjob == %{job | state: :inactive}
  end

  test "activating a named job" do
    name = :newsletter
    spec = "* * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{name: name, schedule: spec, task: fun, state: :inactive}

    :ok = Quantum.add_job(name, job)
    :ok = Quantum.activate_job(name)
    ajob = Quantum.find_job(name)
    assert ajob == %{job | state: :active}
  end

  test "deleting a named job at run time" do
    spec = "* * * * *"
    name = :newsletter
    fun = fn -> :ok end
    job = %Quantum.Job{name: name, schedule: spec, task: fun}
    :ok = Quantum.add_job(name, job)
    djob = Quantum.delete_job(name)
    assert djob.name == name
    assert djob.schedule == spec
    assert !Enum.member? Quantum.jobs, {name, job}
  end

  test "handle_info" do
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    state = %{jobs: [], d: d, h: h, m: m, w: nil, r: 0}
    assert Quantum.handle_info(:tick, state) == {:noreply, state}
  end

  test "handle_call for :which_children" do
    state = %{jobs: [], d: nil, h: nil, m: nil, w: nil, r: 0}
    children = [{Task.Supervisor, :quantum_tasks_sup, :supervisor, [Task.Supervisor]}]
    assert Quantum.handle_call(:which_children, :test, state) == {:reply, children, state}
  end

  test "execute" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    job = %Quantum.Job{schedule: "* * * * *", task: fun}
    state1 = %{jobs: [{nil, job}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state2 = %{jobs: [{nil, job}], d: d, h: h, m: m, w: nil, r: 0}
    assert Quantum.handle_info(:tick, state1) == {:noreply, state2}
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 1
    :ok = Agent.stop(pid)
  end

  test "reboot" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    job = %Quantum.Job{schedule: "@reboot", task: fun}
    {:ok, state} = Quantum.init(%{jobs: [{nil, job}], d: nil, h: nil, m: nil, w: nil, r: nil})
    assert state.jobs == [{nil, job}]
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 1
    :ok = Agent.stop(pid)
  end

end
