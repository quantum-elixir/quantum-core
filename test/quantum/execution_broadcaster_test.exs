defmodule Quantum.ExecutionBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Crontab.CronExpression
  import ExUnit.CaptureLog
  import Quantum.CaptureLogExtend

  alias Quantum.{ExecutionBroadcaster, ExecutionBroadcaster.State, HandoffHelper, Job}
  alias Quantum.Storage.Test, as: TestStorage
  alias Quantum.{TestConsumer, TestProducer}

  # Allow max 10% Latency
  @max_timeout 1_100

  # Timeout until first event arrives
  @init_timeout 15_000

  doctest ExecutionBroadcaster

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :execution_broadcaster_test
  end

  setup tags do
    if tags[:listen_storage] do
      Process.put(:test_pid, self())
    end

    if tags[:manual_dispatch] do
      :ok
    else
      {:ok, producer} = start_supervised({TestProducer, []})

      {{:ok, broadcaster}, _} =
        capture_log_with_return(fn ->
          start_supervised(
            {ExecutionBroadcaster, {__MODULE__, producer, TestStorage, TestScheduler, true}}
          )
        end)

      {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

      {:ok, %{producer: producer, broadcaster: broadcaster, debug_logging: true}}
    end
  end

  describe "add" do
    test "reboot triggers", %{producer: producer} do
      reboot_job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[@reboot])

      # Some schedule that is valid but will not trigger the next 10 years
      non_reboot_job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[* * * * * #{NaiveDateTime.utc_now().year + 1}])

      capture_log(fn ->
        TestProducer.send(producer, {:add, reboot_job})
        TestProducer.send(producer, {:add, non_reboot_job})

        assert_receive {:received, {:execute, ^reboot_job}}, @max_timeout
        refute_receive {:received, {:execute, ^non_reboot_job}}, @max_timeout
      end)
    end

    test "normal schedule triggers once per second", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:received, {:execute, ^job}}, @max_timeout
        assert_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end

    @tag manual_dispatch: true, listen_storage: true
    test "loads last execution time from storage" do
      defmodule TestStorageWithLastExecutionTime do
        @moduledoc false
        use Quantum.Storage.Test

        def last_execution_date(_),
          do: NaiveDateTime.add(NaiveDateTime.utc_now(), -50, :second)
      end

      capture_log(fn ->
        {:ok, producer} = start_supervised({TestProducer, []})

        {:ok, broadcaster} =
          start_supervised(
            {ExecutionBroadcaster,
             {__MODULE__, producer, TestStorageWithLastExecutionTime, TestScheduler, true}}
          )

        {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

        job =
          TestScheduler.new_job()
          |> Job.set_schedule(~e[*]e)

        TestProducer.send(producer, {:add, job})

        assert_receive {:update_last_execution_date, {TestScheduler, date}, _}, @max_timeout

        diff_seconds = NaiveDateTime.diff(NaiveDateTime.utc_now(), date, :second)

        assert diff_seconds >= 50 - 1

        assert_receive {:received, {:execute, ^job}}, @init_timeout

        # Quickly executes until reached current time
        for i <- 0..(diff_seconds - 2) do
          assert_receive {:received, {:execute, ^job}}, 500, "Fast execution #{i} not received"
        end

        # Maybe a little time elapsed in the test?
        for _ <- 0..2 do
          assert_receive {:received, {:execute, ^job}}, 1010
        end

        # Goes back to normal pace
        refute_receive {:received, {:execute, ^job}}, 900
      end)
    end

    @tag listen_storage: true
    test "saves new last execution time in storage", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:update_last_execution_date, {TestScheduler, %NaiveDateTime{}}, _},
                       @max_timeout

        assert_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end

    test "normal schedule in other timezone triggers once per second", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)
        |> Job.set_timezone("Europe/Zurich")

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:received, {:execute, ^job}}, @max_timeout
        assert_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end

    test "impossible schedule will not create a crash", %{producer: producer} do
      # Some schedule that will never trigger
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[1 1 1 1 1 2000])

      assert capture_log(fn ->
               TestProducer.send(producer, {:add, job})

               refute_receive {:received, {:execute, ^job}}, @max_timeout
             end) =~ """
             Invalid Schedule #{inspect(job.schedule)} provided for job #{inspect(job.name)}.
             No matching dates found. The job was removed.
             """
    end

    test "invalid timezone will not create a crash", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)
        |> Job.set_timezone("Foobar")

      assert capture_log(fn ->
               TestProducer.send(producer, {:add, job})

               refute_receive {:received, {:execute, ^job}}, @max_timeout
             end) =~
               "Invalid Timezone #{inspect(job.timezone)} provided for job #{inspect(job.name)}."
    end

    test "will continue to send after new job is added", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      job_new =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*])

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:received, {:execute, ^job}}, @max_timeout

        TestProducer.send(producer, {:add, job_new})

        assert_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end

    test "will recalculate execution timer when a new job is added", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[1 1 1 1 1])

      job_new =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})
        TestProducer.send(producer, {:add, job_new})

        assert_receive {:received, {:execute, ^job_new}}, @max_timeout
      end)
    end

    test "DST creates no problems", %{debug_logging: debug_logging} do
      state = %State{
        jobs: [],
        time: ~N[2018-03-25 00:59:01],
        timer: nil,
        debug_logging: debug_logging,
        storage: TestStorage,
        scheduler: TestScheduler
      }

      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*])
        |> Job.set_timezone("Europe/Zurich")

      assert capture_log(fn ->
               assert {:noreply, [],
                       %{
                         jobs: [
                           {~N[2018-03-25 01:01:00], [^job]}
                         ],
                         time: ~N[2018-03-25 00:59:01],
                         timer: {_, ~N[2018-03-25 01:01:00]}
                       }} = ExecutionBroadcaster.handle_events([{:add, job}], self(), state)
             end) =~ "Next execution time for job #{inspect(job.name)} is not a valid time."
    end
  end

  describe "remove" do
    test "stops triggering after remove", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:received, {:execute, ^job}}, @max_timeout

        TestProducer.send(producer, {:remove, job.name})

        refute_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end

    test "remove inexistent will not crash", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        assert_receive {:received, {:execute, ^job}}, @max_timeout

        TestProducer.send(producer, {:remove, make_ref()})

        assert_receive {:received, {:execute, ^job}}, @max_timeout
      end)
    end
  end

  describe "swarm/handoff" do
    @tag manual_dispatch: true
    test "works" do
      Process.flag(:trap_exit, true)

      {:ok, producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, Old), producer, TestStorage, TestScheduler, true}
        )

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(producer, {:add, job})

      assert_receive {:received, {:execute, ^job}}, @max_timeout

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, New), producer, TestStorage, TestScheduler, true}
        )

      {:ok, new_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_broadcaster, self())

      HandoffHelper.initiate_handoff(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      assert_receive {:received, {:execute, ^job}}, @max_timeout
    end

    @tag manual_dispatch: true
    test "works empty" do
      Process.flag(:trap_exit, true)

      {:ok, producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, Old), producer, TestStorage, TestScheduler, true}
        )

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, New), producer, TestStorage, TestScheduler, true}
        )

      {:ok, new_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_broadcaster, self())

      HandoffHelper.initiate_handoff(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(producer, {:add, job})

      assert_receive {:received, {:execute, ^job}}, @init_timeout
    end
  end

  describe "swarm/resolve_conflict" do
    @tag manual_dispatch: true
    test "works" do
      Process.flag(:trap_exit, true)

      {:ok, old_producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, Old), old_producer, TestStorage, TestScheduler, true}
        )

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      {:ok, new_producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(
          {Module.concat(__MODULE__, New), new_producer, TestStorage, TestScheduler, true}
        )

      {:ok, new_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_broadcaster, self())

      old_job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(old_producer, {:add, old_job})

      new_job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(new_producer, {:add, new_job})

      assert_receive {:received, {:execute, ^old_job}}, @max_timeout
      assert_receive {:received, {:execute, ^new_job}}, @max_timeout

      HandoffHelper.resolve_conflict(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      assert_receive {:received, {:execute, ^old_job}}, @max_timeout
      assert_receive {:received, {:execute, ^new_job}}, @max_timeout
    end
  end
end
