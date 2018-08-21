defmodule Quantum.JobBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.{HandoffHelper, Job, JobBroadcaster, JobBroadcaster.StartOpts}
  alias Quantum.Storage.Test, as: TestStorage
  alias Quantum.TestConsumer

  import ExUnit.CaptureLog
  import Quantum.CaptureLogExtend

  doctest JobBroadcaster

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :job_broadcaster_test
  end

  setup tags do
    if tags[:listen_storage] do
      Process.put(:test_pid, self())
    end

    active_job = TestScheduler.new_job()
    inactive_job = Job.set_state(TestScheduler.new_job(), :inactive)

    init_jobs =
      case tags[:jobs] do
        :both ->
          [active_job, inactive_job]

        :active ->
          [active_job]

        :inactive ->
          [inactive_job]

        _ ->
          []
      end

    broadcaster =
      if tags[:manual_dispatch] do
        nil
      else
        {{:ok, broadcaster}, _} =
          capture_log_with_return(fn ->
            start_supervised(
              {JobBroadcaster,
               %StartOpts{
                 name: __MODULE__,
                 jobs: init_jobs,
                 storage: TestStorage,
                 scheduler: TestScheduler,
                 debug_logging: true
               }}
            )
          end)

        {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

        broadcaster
      end

    {
      :ok,
      broadcaster: broadcaster,
      active_job: active_job,
      inactive_job: inactive_job,
      init_jobs: init_jobs
    }
  end

  describe "init" do
    @tag jobs: :both
    test "config jobs", %{active_job: active_job, inactive_job: inactive_job} do
      refute_receive {:received, {:add, ^inactive_job}}
      assert_receive {:received, {:add, ^active_job}}
    end

    @tag manual_dispatch: true
    test "storage jobs", %{active_job: active_job, inactive_job: inactive_job} do
      capture_log(fn ->
        defmodule FullStorage do
          @moduledoc false

          use Quantum.Storage.Test

          def jobs(_),
            do: [
              TestScheduler.new_job(),
              Job.set_state(TestScheduler.new_job(), :inactive)
            ]
        end

        {:ok, broadcaster} =
          start_supervised(
            {JobBroadcaster,
             %StartOpts{
               name: __MODULE__,
               jobs: [],
               storage: FullStorage,
               scheduler: TestScheduler,
               debug_logging: true
             }}
          )

        {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

        assert_receive {:received, {:add, _}}
        refute_receive {:received, {:add, _}}
      end)
    end
  end

  describe "add" do
    @tag listen_storage: true
    test "active", %{broadcaster: broadcaster, active_job: active_job} do
      assert capture_log(fn ->
               TestScheduler.add_job(broadcaster, active_job)

               assert_receive {:received, {:add, ^active_job}}

               assert_receive {:add_job, {TestScheduler, ^active_job}, _}
             end) =~ "Adding job #Reference"
    end

    test "active (without debug-logging)", %{init_jobs: init_jobs, active_job: active_job} do
      refute capture_log(fn ->
               # Restart JobBroadcaster with debug-logging false
               :ok = stop_supervised(JobBroadcaster)
               :ok = stop_supervised(TestConsumer)

               {:ok, broadcaster} =
                 start_supervised(
                   {JobBroadcaster,
                    %StartOpts{
                      name: __MODULE__,
                      jobs: init_jobs,
                      storage: TestStorage,
                      scheduler: TestScheduler,
                      debug_logging: false
                    }}
                 )

               {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

               TestScheduler.add_job(broadcaster, active_job)

               assert_receive {:received, {:add, ^active_job}}
             end) =~ "Adding job #Reference"
    end

    @tag listen_storage: true
    test "inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      capture_log(fn ->
        TestScheduler.add_job(broadcaster, inactive_job)

        refute_receive {:received, {:add, _}}

        assert_receive {:add_job, {TestScheduler, ^inactive_job}, _}
      end)
    end
  end

  describe "delete" do
    @tag jobs: :active, listen_storage: true
    test "active", %{broadcaster: broadcaster, active_job: active_job} do
      active_job_name = active_job.name

      capture_log(fn ->
        TestScheduler.delete_job(broadcaster, active_job.name)

        assert_receive {:received, {:remove, ^active_job_name}}

        assert_receive {:delete_job, {TestScheduler, ^active_job_name}, _}

        refute Enum.any?(TestScheduler.jobs(broadcaster), fn {key, _} ->
                 key == active_job_name
               end)
      end)
    end

    @tag listen_storage: true
    test "missing", %{broadcaster: broadcaster} do
      capture_log(fn ->
        TestScheduler.delete_job(broadcaster, make_ref())

        refute_receive {:received, {:remove, _}}

        refute_receive {:delete_job, {TestScheduler, _}, _}
      end)
    end

    @tag jobs: :inactive, listen_storage: true
    test "inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      capture_log(fn ->
        inactive_job_name = inactive_job.name

        TestScheduler.delete_job(broadcaster, inactive_job.name)

        refute_receive {:received, {:remove, _}}

        assert_receive {:delete_job, {TestScheduler, ^inactive_job_name}, _}

        refute Enum.any?(TestScheduler.jobs(broadcaster), fn {key, _} ->
                 key == inactive_job.name
               end)
      end)
    end
  end

  describe "change_state" do
    @tag jobs: :active, listen_storage: true
    test "active => inactive", %{broadcaster: broadcaster, active_job: active_job} do
      active_job_name = active_job.name

      capture_log(fn ->
        TestScheduler.deactivate_job(broadcaster, active_job.name)

        assert_receive {:received, {:remove, ^active_job_name}}

        assert_receive {:update_job_state, {TestScheduler, _, _}, _}
      end)
    end

    @tag jobs: :inactive, listen_storage: true
    test "inactive => active", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      capture_log(fn ->
        TestScheduler.activate_job(broadcaster, inactive_job.name)

        active_job = Job.set_state(inactive_job, :active)

        assert_receive {:received, {:add, ^active_job}}

        assert_receive {:update_job_state, {TestScheduler, _, _}, _}
      end)
    end

    @tag jobs: :active, listen_storage: true
    test "active => active", %{broadcaster: broadcaster, active_job: active_job} do
      # Initial
      assert_receive {:received, {:add, ^active_job}}

      capture_log(fn ->
        TestScheduler.activate_job(broadcaster, active_job.name)

        refute_receive {:received, {:add, ^active_job}}

        refute_receive {:update_job_state, {TestScheduler, _, _}, _}
      end)
    end

    @tag jobs: :inactive, listen_storage: true
    test "inactive => inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      inactive_job_name = inactive_job.name

      capture_log(fn ->
        TestScheduler.deactivate_job(broadcaster, inactive_job.name)

        refute_receive {:received, {:remove, ^inactive_job_name}}

        refute_receive {:update_job_state, {TestScheduler, _, _}, _}
      end)
    end

    @tag listen_storage: true
    test "missing", %{broadcaster: broadcaster} do
      capture_log(fn ->
        TestScheduler.deactivate_job(broadcaster, make_ref())
        TestScheduler.activate_job(broadcaster, make_ref())

        refute_receive {:received, {:remove, _}}
        refute_receive {:received, {:add, _}}
        refute_receive {:update_job_state, {TestScheduler, _, _}, _}
      end)
    end
  end

  describe "delete_all" do
    @tag jobs: :both, listen_storage: true
    test "only active jobs", %{
      broadcaster: broadcaster,
      active_job: active_job,
      inactive_job: inactive_job
    } do
      active_job_name = active_job.name
      inactive_job_name = inactive_job.name

      capture_log(fn ->
        TestScheduler.delete_all_jobs(broadcaster)

        refute_receive {:received, {:remove, ^inactive_job_name}}
        assert_receive {:received, {:remove, ^active_job_name}}

        assert_receive {:purge, TestScheduler, _}
      end)
    end
  end

  describe "jobs" do
    @tag jobs: :both
    test "gets all jobs", %{
      broadcaster: broadcaster,
      active_job: active_job,
      inactive_job: inactive_job
    } do
      active_job_name = active_job.name
      inactive_job_name = inactive_job.name

      assert [{^active_job_name, %Job{}}, {^inactive_job_name, %Job{}}] =
               TestScheduler.jobs(broadcaster)
    end
  end

  @tag jobs: :active
  describe "find_job" do
    test "finds correct one", %{broadcaster: broadcaster, active_job: active_job} do
      active_job_name = active_job.name

      assert active_job == TestScheduler.find_job(broadcaster, active_job_name)
    end
  end

  describe "swarm/handoff" do
    test "works" do
      Process.flag(:trap_exit, true)

      job = TestScheduler.new_job()
      job_name = job.name

      %{start: {JobBroadcaster, f, a}} =
        JobBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, Old),
          jobs: [job],
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, old_job_broadcaster} = apply(JobBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_job_broadcaster, self())

      %{start: {JobBroadcaster, f, a}} =
        JobBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, New),
          jobs: [],
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, new_job_broadcaster} = apply(JobBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_job_broadcaster, self())

      HandoffHelper.initiate_handoff(old_job_broadcaster, new_job_broadcaster)

      assert TestScheduler.jobs(new_job_broadcaster) == [{job_name, job}]

      assert_receive {:EXIT, ^old_job_broadcaster, :shutdown}
    end
  end

  describe "swarm/resolve_conflict" do
    test "works" do
      Process.flag(:trap_exit, true)

      job_1 = TestScheduler.new_job()
      job_1_name = job_1.name

      job_2 = TestScheduler.new_job()
      job_2_name = job_2.name

      %{start: {JobBroadcaster, f, a}} =
        JobBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, Old),
          jobs: [job_1],
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, old_job_broadcaster} = apply(JobBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_job_broadcaster, self())

      %{start: {JobBroadcaster, f, a}} =
        JobBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, New),
          jobs: [job_2],
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, new_job_broadcaster} = apply(JobBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_job_broadcaster, self())

      HandoffHelper.resolve_conflict(old_job_broadcaster, new_job_broadcaster)

      resulting_jobs = TestScheduler.jobs(new_job_broadcaster)

      assert Enum.member?(resulting_jobs, {job_1_name, job_1})
      assert Enum.member?(resulting_jobs, {job_2_name, job_2})

      assert_receive {:EXIT, ^old_job_broadcaster, :shutdown}
    end
  end
end
