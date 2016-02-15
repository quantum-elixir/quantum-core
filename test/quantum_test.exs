defmodule QuantumTest do
  use ExUnit.Case

  defp job_names, do: ["test_job", :test_job, 'test_job']

  setup do
    Quantum.delete_all_jobs
  end

  test "adding a job at run time" do
    spec = "1 * * * *"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: spec, task: fun, nodes: [node()]}
    assert Enum.member? Quantum.jobs, {nil, job}
  end

  test "adding a named job as options at run time" do
    for name <- job_names do
      spec = "1 * * * *"
      fun = fn -> :ok end
      job_otps = %{schedule: spec, task: fun}
      job = %Quantum.Job{} |> Map.merge(job_otps)
      :ok = Quantum.add_job(name, job_otps)
      assert Enum.member? Quantum.jobs, {name, %{job | name: name,
                                                       nodes: [node()]}}
    end
  end

  test "adding a named job struct at run time" do
    for name <- job_names do
      spec = "1 * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{schedule: spec, task: fun}
      :ok = Quantum.add_job(name, job)
      assert Enum.member? Quantum.jobs, {name, %{job | name: name,
                                                       nodes: [node()]}}
    end
  end

  test "adding a unnamed job at run time" do
    spec = "1 * * * *"
    fun = fn -> :ok end
    job = %Quantum.Job{schedule: spec, task: fun}
    :ok = Quantum.add_job(job)
    assert Enum.member? Quantum.jobs, {nil, %{job | nodes: [node()]}}
  end

  test "adding a job at run time with atom expression" do
    spec = :"@daily"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: Atom.to_string(spec), task: fun}
    assert Enum.member? Quantum.jobs, {nil, %{job | nodes: [node()]}}
  end

  test "adding a job at run time with uppercase string" do
    spec = "@HOURLY"
    fun = fn -> :ok end
    :ok = Quantum.add_job(spec, fun)
    job = %Quantum.Job{schedule: String.downcase(spec), task: fun}
    assert Enum.member? Quantum.jobs, {nil, %{job | nodes: [node()]}}
  end

  test "finding a named job" do
    for name <- job_names do
      spec = "* * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{schedule: spec, task: fun}
      :ok = Quantum.add_job(name, job)
      fjob = Quantum.find_job(name)
      assert fjob.name == name
      assert fjob.schedule == spec
      assert fjob.nodes == [node()]
    end
  end

  test "deactivating a named job" do
    for name <- job_names do
      spec = "* * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{name: name, schedule: spec, task: fun}
      :ok = Quantum.add_job(name, job)
      :ok = Quantum.deactivate_job(name)
      sjob = Quantum.find_job(name)
      assert sjob == %{job | state: :inactive}
    end
  end

  test "activating a named job" do
    for name <- job_names do
      spec = "* * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{name: name, schedule: spec, task: fun, state: :inactive}

      :ok = Quantum.add_job(name, job)
      :ok = Quantum.activate_job(name)
      ajob = Quantum.find_job(name)
      assert ajob == %{job | state: :active}
    end
  end

  test "deleting a named job at run time" do
    for name <- job_names do
      spec = "* * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{name: name, schedule: spec, task: fun}
      :ok = Quantum.add_job(name, job)
      djob = Quantum.delete_job(name)
      assert djob.name == name
      assert djob.schedule == spec
      assert !Enum.member? Quantum.jobs, {name, job}
    end
  end

  test "deleting all jobs" do
    for name <- job_names do
      spec = "* * * * *"
      fun = fn -> :ok end
      job = %Quantum.Job{name: name, schedule: spec, task: fun}
      :ok = Quantum.add_job(name, job)
    end
    assert Enum.count(Quantum.jobs) == 3
    Quantum.delete_all_jobs
    assert Quantum.jobs == []
  end

  test "prevent duplicate job names" do
    # note that "test_job", :test_job and 'test_job' are regarded as different names
    job = %Quantum.Job{schedule: "* * * * *", task: fn -> :ok end}
    assert Quantum.add_job(:test_job, job) == :ok
    assert Quantum.add_job(:test_job, job) == :error
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

  test "execute for current node" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = %Quantum.Job{schedule: "* * * * *", task: fun}
    state1 = %{jobs: [{nil, job}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state3 = Quantum.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 1
    job = %{job | pid: Agent.get(pid1, fn(n) -> n end)}
    state2 = %{jobs: [{nil, job}], d: d, h: h, m: m, w: nil, r: 0}
    assert state3 == {:noreply, state2}
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  test "skip for current node" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    job = %Quantum.Job{schedule: "* * * * *", task: fun, nodes: [:remote@node]}
    state1 = %{jobs: [{nil, job}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state2 = %{jobs: [{nil, job}], d: d, h: h, m: m, w: nil, r: 0}
    assert Quantum.handle_info(:tick, state1) == {:noreply, state2}
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 0
    :ok = Agent.stop(pid)
  end

  test "reboot" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)
    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = %Quantum.Job{schedule: "@reboot", task: fun}
    {:ok, state} = Quantum.init(%{jobs: [{nil, job}], d: nil, h: nil, m: nil, w: nil, r: nil})
    :timer.sleep(500)
    job = %{job | pid: Agent.get(pid1, fn(n) -> n end)}
    assert state.jobs == [{nil, job}]
    assert Agent.get(pid2, fn(n) -> n end) == 1
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  test "overlap, first start" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = %Quantum.Job{schedule: "* * * * *", task: fun, overlap: false}
    state1 = %{jobs: [{nil, job}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state3 = Quantum.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 1
    job = %{job | pid: Agent.get(pid1, fn(n) -> n end)}
    state2 = %{jobs: [{nil, job}], d: d, h: h, m: m, w: nil, r: 0}
    assert state3 == {:noreply, state2}
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  test "overlap, second start" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = %Quantum.Job{schedule: "* * * * *", task: fun, overlap: false, pid: pid1}
    state1 = %{jobs: [{nil, job}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state3 = Quantum.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 0
    job = %{job | pid: pid1}
    state2 = %{jobs: [{nil, job}], d: d, h: h, m: m, w: nil, r: 0}
    assert state3 == {:noreply, state2}
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

end
