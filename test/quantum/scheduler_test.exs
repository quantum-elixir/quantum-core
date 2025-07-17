defmodule Quantum.SchedulerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.Job
  alias Quantum.RunStrategy.Random

  import ExUnit.CaptureLog

  import Crontab.CronExpression

  defmodule Scheduler do
    @moduledoc false

    use Quantum, otp_app: :scheduler_test
  end

  @defaults %{
    schedule: "*/7",
    overlap: false,
    timezone: "Europe/Zurich"
  }

  defmodule DefaultConfigScheduler do
    @moduledoc false

    use Quantum, otp_app: :scheduler_test
  end

  defmodule ZeroTimeoutScheduler do
    @moduledoc false

    use Quantum, otp_app: :scheduler_test
  end

  setup_all do
    Application.put_env(:scheduler_test, Scheduler, jobs: [])

    Application.put_env(
      :scheduler_test,
      DefaultConfigScheduler,
      jobs: [],
      schedule: @defaults.schedule,
      overlap: @defaults.overlap,
      timezone: @defaults.timezone
    )

    Application.put_env(:scheduler_test, ZeroTimeoutScheduler, timeout: 0, jobs: [])
  end

  setup context do
    schedulers = Map.get(context, :schedulers, [])

    for scheduler <- schedulers do
      {:ok, _pid} = start_supervised(scheduler)
    end

    :ok
  end

  describe "new_job/0" do
    test "returns Quantum.Job struct" do
      %Job{schedule: schedule, overlap: overlap, timezone: timezone} = Scheduler.new_job()

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

  describe "add_job/2" do
    @tag schedulers: [Scheduler]
    test "adding a job at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end

      capture_log(fn ->
        :ok = Scheduler.add_job({spec, fun})

        assert Enum.any?(Scheduler.jobs(), fn {_, %Job{schedule: schedule, task: task}} ->
                 schedule == spec && task == fun
               end)
      end)
    end

    @tag schedulers: [Scheduler]
    test "adding a named job struct at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end

      job =
        Scheduler.new_job()
        |> Job.set_name(:test_job)
        |> Job.set_schedule(spec)
        |> Job.set_task(fun)

      capture_log(fn ->
        :ok = Scheduler.add_job(job)

        assert Enum.member?(Scheduler.jobs(), {
                 :test_job,
                 %{job | run_strategy: %Random{nodes: :cluster}}
               })
      end)
    end

    @tag schedulers: [Scheduler]
    test "adding a named {m, f, a} job at run time" do
      spec = ~e[1 * * * *]
      task = {IO, :puts, ["Tick"]}

      job =
        Scheduler.new_job()
        |> Job.set_name(:ticker)
        |> Job.set_schedule(spec)
        |> Job.set_task(task)

      capture_log(fn ->
        :ok = Scheduler.add_job(job)

        assert Enum.member?(Scheduler.jobs(), {
                 :ticker,
                 %{job | run_strategy: %Random{nodes: :cluster}}
               })
      end)
    end

    @tag schedulers: [Scheduler]
    test "adding a unnamed job at run time" do
      spec = ~e[1 * * * *]
      fun = fn -> :ok end

      job =
        Scheduler.new_job()
        |> Job.set_schedule(spec)
        |> Job.set_task(fun)

      capture_log(fn ->
        :ok = Scheduler.add_job(job)
        assert Enum.member?(Scheduler.jobs(), {job.name, job})
      end)
    end
  end

  @tag schedulers: [Scheduler]
  test "finding a named job" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end

    job =
      Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)

    capture_log(fn ->
      :ok = Scheduler.add_job(job)
      fjob = Scheduler.find_job(:test_job)
      assert fjob.name == :test_job
      assert fjob.schedule == spec
      assert fjob.run_strategy == %Random{nodes: :cluster}
    end)
  end

  @tag schedulers: [Scheduler]
  test "deactivating a named job" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end

    job =
      Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)

    capture_log(fn ->
      :ok = Scheduler.add_job(job)
      :ok = Scheduler.deactivate_job(:test_job)
      sjob = Scheduler.find_job(:test_job)
      assert sjob == %{job | state: :inactive}
    end)
  end

  @tag schedulers: [Scheduler]
  test "activating a named job" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end

    job =
      Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_state(:inactive)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)

    capture_log(fn ->
      :ok = Scheduler.add_job(job)
      :ok = Scheduler.activate_job(:test_job)
      ajob = Scheduler.find_job(:test_job)
      assert ajob == %{job | state: :active}
    end)
  end

  @tag schedulers: [Scheduler]
  test "deleting a named job at run time" do
    spec = ~e[* * * * *]
    fun = fn -> :ok end

    job =
      Scheduler.new_job()
      |> Job.set_name(:test_job)
      |> Job.set_schedule(spec)
      |> Job.set_task(fun)

    capture_log(fn ->
      :ok = Scheduler.add_job(job)
      :ok = Scheduler.delete_job(:test_job)
      assert !Enum.member?(Scheduler.jobs(), {:test_job, job})
    end)
  end

  @tag schedulers: [Scheduler]
  test "deleting all jobs" do
    capture_log(fn ->
      for i <- 1..3 do
        name = String.to_atom("test_job_" <> Integer.to_string(i))
        spec = ~e[* * * * *]
        fun = fn -> :ok end

        job =
          Scheduler.new_job()
          |> Job.set_name(name)
          |> Job.set_schedule(spec)
          |> Job.set_task(fun)

        :ok = Scheduler.add_job(job)
      end

      assert Enum.count(Scheduler.jobs()) == 3
      Scheduler.delete_all_jobs()
      assert Scheduler.jobs() == []
    end)
  end

  @tag schedulers: [ZeroTimeoutScheduler]
  test "timeout can be configured for genserver correctly" do
    job =
      ZeroTimeoutScheduler.new_job()
      |> Job.set_name(:tmpjob)
      |> Job.set_schedule(~e[* */5 * * *])
      |> Job.set_task(fn -> :ok end)

    capture_log(fn ->
      ZeroTimeoutScheduler.add_job(job)

      assert {:timeout, _} = catch_exit(ZeroTimeoutScheduler.find_job(:tmpjob))

      # Ensure that log message is contained
      Process.sleep(100)
    end)
  end
end
