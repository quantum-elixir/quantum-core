defmodule Quantum.SchedulerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.Job
  alias Quantum.RunStrategy.Random

  import Crontab.CronExpression
  import ExUnit.CaptureLog

  defmodule Scheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :scheduler_test
  end

  @defaults %{
    schedule: "*/7",
    overlap: false,
    timezone: "Europe/Zurich"
  }

  defmodule DefaultConfigScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :scheduler_test
  end

  defmodule ZeroTimeoutScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :scheduler_test
  end

  setup_all do
    Application.put_env(:scheduler_test, Scheduler, jobs: [])

    Application.put_env(:scheduler_test, DefaultConfigScheduler, [
      jobs: [],
      schedule: @defaults.schedule,
      overlap: @defaults.overlap,
      timezone: @defaults.timezone
    ])

    Application.put_env(:scheduler_test, ZeroTimeoutScheduler, timeout: 0, jobs: [])
  end

  setup context do
    schedulers = Map.get(context, :schedulers, [])

    for scheduler <- schedulers do
      scheduler.start_link([])
    end

    :ok
  end

  describe "new_job/0" do
    test "returns Quantum.Job struct" do
      %Job{schedule: schedule, overlap: overlap, timezone: timezone} =
        Scheduler.new_job()

      assert schedule == nil
      assert overlap == true
      assert timezone == :utc
    end

    test "has defaults set" do
      %Job{schedule: schedule, overlap: overlap, timezone: timezone} =
        DefaultConfigScheduler.new_job()

      assert schedule == ~e[#{@defaults.schedule}]
      assert overlap == @defaults.overlap
      assert timezone == @defaults.timezone
    end
  end

  @tag schedulers: [Scheduler]
  test "adding a job at run time" do
    spec = ~e[1 * * * *]
    fun = fn -> :ok end
    :ok = Scheduler.add_job({spec, fun})
    job = Scheduler.new_job()
    |> Job.set_schedule(spec)
    |> Job.set_task(fun)
    assert Enum.member? Scheduler.jobs, {nil, job}
  end

  @tag schedulers: [Scheduler]
  describe "add_job/2" do
    test "adding a job at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end

      :ok = Scheduler.add_job({spec, fun})
      job = Scheduler.new_job()
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)
      assert Enum.member? Scheduler.jobs, {nil, job}
    end

    @tag schedulers: [Scheduler]
    test "adding a named job struct at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end
      job = Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)
      :ok = Scheduler.add_job(job)
      assert Enum.member? Scheduler.jobs, {:test_job, %{job | run_strategy: %Random{nodes: :cluster}}}
    end

    @tag schedulers: [Scheduler]
    test "adding a named {m, f, a} jpb at run time" do
      spec = ~e[1 * * * *]
      task = {IO, :puts, ["Tick"]}
      job = Scheduler.new_job()
      |> Job.set_name(:ticker)
      |> Job.set_schedule(spec)
      |> Job.set_task(task)
      :ok = Scheduler.add_job(job)
      assert Enum.member? Scheduler.jobs, {:ticker, %{job | run_strategy: %Random{nodes: :cluster}}}
    end

    @tag schedulers: [Scheduler]
    test "adding a unnamed job at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end
      job = Scheduler.new_job()
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)
      :ok = Scheduler.add_job(job)
      assert Enum.member? Scheduler.jobs, {nil, job}
    end
  end

  @tag schedulers: [Scheduler]
  test "finding a named job" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end
    job = Scheduler.new_job()
    |> Job.set_name(:test_job)
    |> Job.set_schedule(spec)
    |> Job.set_task(fun)
    :ok = Scheduler.add_job(job)
    fjob = Scheduler.find_job(:test_job)
    assert fjob.name == :test_job
    assert fjob.schedule == spec
    assert fjob.run_strategy == %Random{nodes: :cluster}
  end

  @tag schedulers: [Scheduler]
  test "deactivating a named job" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end
    job = Scheduler.new_job()
    |> Job.set_name(:test_job)
    |> Job.set_schedule(spec)
    |> Job.set_task(fun)

    :ok = Scheduler.add_job(job)
    :ok = Scheduler.deactivate_job(:test_job)
    sjob = Scheduler.find_job(:test_job)
    assert sjob == %{job | state: :inactive}
  end

  @tag schedulers: [Scheduler]
  test "activating a named job" do
      spec = ~e[* * * * *]
      fun = fn -> :ok end

      job = Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_state(:inactive)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)

      :ok = Scheduler.add_job(job)
      :ok = Scheduler.activate_job(:test_job)
      ajob = Scheduler.find_job(:test_job)
      assert ajob == %{job | state: :active}
  end

  @tag schedulers: [Scheduler]
  test "deleting a named job at run time" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end

    job = Scheduler.new_job()
    |> Job.set_name(:test_job)
    |> Job.set_schedule(spec)
    |> Job.set_task(fun)

    :ok = Scheduler.add_job(job)
    :ok = Scheduler.delete_job(:test_job)
    assert !Enum.member? Scheduler.jobs, {:test_job, job}
  end

  @tag schedulers: [Scheduler]
  test "deleting all jobs" do
    for i <- 1..3 do
      name = String.to_atom("test_job_" <> Integer.to_string(i))
      spec = ~e[* * * * *]
      fun = fn -> :ok end
      job = Scheduler.new_job()
      |> Job.set_name(name)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)
      :ok = Scheduler.add_job(job)
    end
    assert Enum.count(Scheduler.jobs) == 3
    Scheduler.delete_all_jobs
    assert Scheduler.jobs == []
  end

  @tag schedulers: [Scheduler]
  test "prevent duplicate job names" do
    job = Scheduler.new_job()
    |> Job.set_name(:test_job)
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_task(fn -> :ok end)

    assert Scheduler.add_job(job) == :ok
    assert Scheduler.add_job(job) == :error
  end

  @tag schedulers: [Scheduler]
  test "execute for current node" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)

    start_date = NaiveDateTime.utc_now
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
    |> NaiveDateTime.add(-1)

    end_date = start_date
    |> NaiveDateTime.add(1)

    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end

    job = Scheduler.new_job()
    |> Job.set_schedule(~e[* * * * *]e)
    |> Job.set_task(fun)

    state1 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: start_date, reboot: false}
    state3 = Quantum.Runner.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 1
    job = %{job | pids: [{node(), Agent.get(pid1, fn(n) -> n end)}]}
    state2 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: end_date, reboot: false}
    assert state3 == {:noreply, state2}
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  test "skip for current node" do
    {:ok, pid} = Agent.start_link(fn -> 0 end)

    start_date = NaiveDateTime.utc_now
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
    |> NaiveDateTime.add(-1)

    end_date = start_date
    |> NaiveDateTime.add(1)

    fun = fn -> Agent.update(pid, fn(n) -> n + 1 end) end
    job = Scheduler.new_job()
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_task(fun)
    |> Job.set_run_strategy(%Random{nodes: [:remote@node]})
    state1 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: start_date, reboot: false}
    state2 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: end_date, reboot: false}
    capture_log(fn ->
      assert Quantum.Runner.handle_info(:tick, state1) == {:noreply, state2}
    end)
    :timer.sleep(500)
    assert Agent.get(pid, fn(n) -> n end) == 0
    :ok = Agent.stop(pid)
  end

  @tag schedulers: [Scheduler]
  test "reboot" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)
    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = Scheduler.new_job()
    |> Job.set_schedule(~e[@reboot])
    |> Job.set_task(fun)
    {:ok, state} = Quantum.Runner.init(%{opts: Scheduler.config(), jobs: [{nil, job}], reboot: true})
    :timer.sleep(500)
    job = %{job | pids: [{node(), Agent.get(pid1, fn(n) -> n end)}]}
    assert state.jobs == [{nil, job}]
    assert Agent.get(pid2, fn(n) -> n end) == 1
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  @tag schedulers: [Scheduler]
  test "overlap, first start" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)

    start_date = NaiveDateTime.utc_now
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
    |> NaiveDateTime.add(-1)

    end_date = start_date
    |> NaiveDateTime.add(1)

    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = Scheduler.new_job()
    |> Job.set_schedule(~e[* * * * *]e)
    |> Job.set_overlap(false)
    |> Job.set_task(fun)

    state1 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: start_date, reboot: false}
    state3 = Quantum.Runner.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 1

    job = %{job | pids: [{node(), Agent.get(pid1, fn(n) -> n end)}]}

    state2 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: end_date, reboot: false}

    assert state3 == {:noreply, state2}

    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  test "overlap, second start" do
    {:ok, pid1} = Agent.start_link(fn -> nil end)
    {:ok, pid2} = Agent.start_link(fn -> 0 end)

    start_date = NaiveDateTime.utc_now
    # Reset MS
    |> NaiveDateTime.to_erl
    |> NaiveDateTime.from_erl!
    |> NaiveDateTime.add(-1)

    end_date = start_date
    |> NaiveDateTime.add(1)

    fun = fn ->
      fun_pid = self()
      Agent.update(pid1, fn(_) -> fun_pid end)
      Agent.update(pid2, fn(n) -> n + 1 end)
    end
    job = Scheduler.new_job()
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_overlap(false)
    |> Job.set_task(fun)
    |> Map.put(:pids, [{node(), pid1}])
    state1 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: start_date, reboot: false}
    state3 = Quantum.Runner.handle_info(:tick, state1)
    :timer.sleep(500)
    assert Agent.get(pid2, fn(n) -> n end) == 0
    job = %{job | pids: [{node(), pid1}]}
    state2 = %{opts: Scheduler.config(), jobs: [{nil, job}], date: end_date, reboot: false}
    assert state3 == {:noreply, state2}
    :ok = Agent.stop(pid2)
    :ok = Agent.stop(pid1)
  end

  @tag schedulers: [Scheduler]
  test "do not crash sibling jobs when a job crashes" do
    fun = fn ->
      receive do
        :ping -> :pong
      end
    end

    job_sibling = Scheduler.new_job()
    |> Job.set_name(:job_sibling)
    |> Job.set_schedule(~e[* * * * *]e)
    |> Job.set_task(fun)

    assert Scheduler.add_job(job_sibling) == :ok

    job_to_crash = Scheduler.new_job()
    |> Job.set_name(:job_to_crash)
    |> Job.set_schedule(~e[* * * * *]e)
    |> Job.set_task(fun)

    assert Scheduler.add_job(job_to_crash) == :ok

    assert Enum.count(Scheduler.jobs) == 2

    send(Scheduler.Runner, :tick)

    %Job{pids: [{_, pid_sibling}]} = Scheduler.find_job(:job_sibling)
    %Job{pids: [{_, pid_to_crash}]} = Scheduler.find_job(:job_to_crash)

    # both processes are alive
    :ok = ensure_alive(pid_sibling)
    :ok = ensure_alive(pid_to_crash)

    # Stop the job with non-normal reason
    Process.exit(pid_to_crash, :shutdown)

    ref_sibling = Process.monitor(pid_sibling)
    ref_to_crash = Process.monitor(pid_to_crash)

    # Wait until the job to crash is dead
    assert_receive {:DOWN, ^ref_to_crash, _, _, _}

    # sibling job shouldn't crash
    refute_receive {:DOWN, ^ref_sibling, _, _, _}
  end

  @tag schedulers: [Scheduler]
  test "preserve state if one of the jobs crashes" do
    job1 = Scheduler.new_job()
    |> Job.set_schedule(~e[* * * * *])
    |> Job.set_task(fn -> :ok end)
    assert Scheduler.add_job(job1) == :ok

    fun = fn ->
      receive do
        :ping -> :pong
      end
    end

    job_to_crash = Scheduler.new_job()
    |> Job.set_name(:job_to_crash)
    |> Job.set_schedule(~e[* * * * *]e)
    |> Job.set_task(fun)

    assert Scheduler.add_job(job_to_crash) == :ok

    assert Enum.count(Scheduler.jobs) == 2

    send(Scheduler.Runner, :tick)

    assert Enum.count(Scheduler.jobs) == 2

    %Job{pids: [{_, pid_to_crash}]} = Scheduler.find_job(:job_to_crash)

    # ensure process to crash is alive
    :ok = ensure_alive(pid_to_crash)

    # Stop the job with non-normal reason
    Process.exit(pid_to_crash, :shutdown)

    # Wait until the job is dead
    ref = Process.monitor(pid_to_crash)
    assert_receive {:DOWN, ^ref, _, _, _}

    # ensure there is a new process registered for Quantum
    # in case Quantum process gets restarted because of
    # the crashed job
    :ok = ensure_registered(Scheduler.Runner)

    # after process crashed we should still have 2 jobs scheduled
    assert Enum.count(Scheduler.jobs) == 2
  end

  @tag schedulers: [ZeroTimeoutScheduler]
  test "timeout can be configured for genserver correctly" do
    job = ZeroTimeoutScheduler.new_job()
    |> Job.set_name(:tmpjob)
    |> Job.set_schedule(~e[* */5 * * *])
    |> Job.set_task(fn -> :ok end)

    assert catch_exit(ZeroTimeoutScheduler.add_job(job)) ==
      {:timeout, {GenServer, :call, [ZeroTimeoutScheduler.Runner, {:find_job, :tmpjob}, 0]}}
  end

  # loop until given process is alive
  defp ensure_alive(pid) do
    case Process.alive?(pid) do
      false ->
        :timer.sleep(10)
        ensure_alive(pid)
      true -> :ok
    end
  end

  # loop until given process is registered
  defp ensure_registered(registered_process) do
    case Process.whereis(registered_process) do
      nil ->
        :timer.sleep(10)
        ensure_registered(registered_process)
      _ -> :ok
    end
  end
end
