defmodule Quantum.JobBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.JobBroadcaster
  alias Quantum.TestConsumer
  alias Quantum.Job

  doctest JobBroadcaster

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :job_broadcaster_test
  end

  setup tags do
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

    {:ok, broadcaster} = start_supervised({JobBroadcaster, {__MODULE__, init_jobs}})
    {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

    {
      :ok,
      %{
        broadcaster: broadcaster,
        active_job: active_job,
        inactive_job: inactive_job
      }
    }
  end

  describe "init" do
    @tag jobs: :both
    test "config jobs", %{active_job: active_job, inactive_job: inactive_job} do
      refute_receive {:received, {:add, ^inactive_job}}
      assert_receive {:received, {:add, ^active_job}}
    end
  end

  describe "add" do
    test "active", %{broadcaster: broadcaster, active_job: active_job} do
      TestScheduler.add_job(broadcaster, active_job)

      assert_receive {:received, {:add, ^active_job}}
    end

    test "inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      TestScheduler.add_job(broadcaster, inactive_job)

      refute_receive {:received, {:add, _}}
    end
  end

  describe "delete" do
    @tag jobs: :active
    test "active", %{broadcaster: broadcaster, active_job: active_job} do
      active_job_name = active_job.name

      TestScheduler.delete_job(broadcaster, active_job.name)

      assert_receive {:received, {:remove, ^active_job_name}}
    end

    test "missing", %{broadcaster: broadcaster} do
      TestScheduler.delete_job(broadcaster, make_ref())

      refute_receive {:received, {:remove, _}}
    end

    @tag jobs: :inactive
    test "inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      TestScheduler.delete_job(broadcaster, inactive_job.name)

      refute_receive {:received, {:remove, _}}
    end
  end

  describe "change_state" do
    @tag jobs: :active
    test "active => inactive", %{broadcaster: broadcaster, active_job: active_job} do
      active_job_name = active_job.name

      TestScheduler.deactivate_job(broadcaster, active_job.name)

      assert_receive {:received, {:remove, ^active_job_name}}
    end

    @tag jobs: :inactive
    test "inactive => active", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      TestScheduler.activate_job(broadcaster, inactive_job.name)

      active_job = Job.set_state(inactive_job, :active)

      assert_receive {:received, {:add, ^active_job}}
    end

    @tag jobs: :active
    test "active => active", %{broadcaster: broadcaster, active_job: active_job} do
      # Initial
      assert_receive {:received, {:add, ^active_job}}

      TestScheduler.activate_job(broadcaster, active_job.name)

      refute_receive {:received, {:add, ^active_job}}
    end

    @tag jobs: :inactive
    test "inactive => inactive", %{broadcaster: broadcaster, inactive_job: inactive_job} do
      inactive_job_name = inactive_job.name

      TestScheduler.deactivate_job(broadcaster, inactive_job.name)

      refute_receive {:received, {:remove, ^inactive_job_name}}
    end

    test "missing", %{broadcaster: broadcaster} do
      TestScheduler.deactivate_job(broadcaster, make_ref())
      TestScheduler.activate_job(broadcaster, make_ref())

      refute_receive {:received, {:remove, _}}
      refute_receive {:received, {:add, _}}
    end
  end

  describe "delete_all" do
    @tag jobs: :both
    test "only active jobs", %{
      broadcaster: broadcaster,
      active_job: active_job,
      inactive_job: inactive_job
    } do
      active_job_name = active_job.name
      inactive_job_name = inactive_job.name

      TestScheduler.delete_all_jobs(broadcaster)

      refute_receive {:received, {:remove, ^inactive_job_name}}
      assert_receive {:received, {:remove, ^active_job_name}}
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
end
