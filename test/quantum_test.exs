defmodule QuantumTest do
  use ExUnit.Case

  test "adding a job at run time" do
    spec = "1 * * * *"
    job = fn -> :ok end
    :ok = Quantum.add_job(spec, job)
    assert Enum.member? Quantum.jobs, {spec, job}
  end

  test "adding a job at run time with atom expression" do
    spec = :"@daily"
    job = fn -> :ok end
    :ok = Quantum.add_job(spec, job)
    assert Enum.member? Quantum.jobs, {"@daily", job}
  end

  test "adding a job at run time with uppercase string" do
    spec = "@HOURLY"
    job = fn -> :ok end
    :ok = Quantum.add_job(spec, job)
    assert Enum.member? Quantum.jobs, {"@hourly", job}
  end
  
  test "handle_info" do
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    state = %{jobs: [], d: d, h: h, m: m, w: nil, r: 0}
    assert Quantum.handle_info(:tick, state) == {:noreply, state}
  end
  
  test "execute" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    {d, {h, m, _}} = :calendar.now_to_universal_time(:os.timestamp)
    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    state1 = %{jobs: [{"* * * * *", fun}], d: d, h: h, m: m - 1, w: nil, r: 0}
    state2 = %{jobs: [{"* * * * *", fun}], d: d, h: h, m: m, w: nil, r: 0}
    assert Quantum.handle_info(:tick, state1) == {:noreply, state2}
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 1
    :ok = Agent.stop(pid)
  end

  test "reboot" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    {:ok, state} = Quantum.init(%{jobs: [{"@reboot", fun}], d: nil, h: nil, m: nil, w: nil, r: nil})
    assert state.jobs == [{"@reboot", fun}]
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 1
    :ok = Agent.stop(pid)
  end

end
