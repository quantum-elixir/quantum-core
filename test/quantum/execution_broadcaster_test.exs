defmodule Quantum.ExecutionBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Crontab.CronExpression
  import ExUnit.CaptureLog
  import Quantum.CaptureLogExtend

  alias Quantum.ClockBroadcaster.Event, as: ClockEvent
  alias Quantum.ExecutionBroadcaster
  alias Quantum.ExecutionBroadcaster.Event, as: ExecuteEvent
  alias Quantum.ExecutionBroadcaster.StartOpts
  alias Quantum.HandoffHelper
  alias Quantum.Job
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
      producer = start_supervised!({TestProducer, []})

      {broadcaster, _} =
        capture_log_with_return(fn ->
          start_supervised!(
            {ExecutionBroadcaster,
             %StartOpts{
               name: __MODULE__,
               job_broadcaster_reference: producer,
               clock_broadcaster_reference: producer,
               storage: TestStorage,
               scheduler: TestScheduler,
               debug_logging: true
             }}
          )
        end)

      start_supervised!({TestConsumer, [broadcaster, self()]})

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

        assert_receive {:received, %ExecuteEvent{job: ^reboot_job}}, @max_timeout
        refute_receive {:received, %ExecuteEvent{job: ^non_reboot_job}}, @max_timeout
      end)
    end

    test "normal schedule triggers once per second", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        spawn(fn ->
          now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
          TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

          Process.sleep(1_000)

          TestProducer.send(producer, %ClockEvent{
            time: NaiveDateTime.add(now, 1, :second),
            catch_up: false
          })
        end)

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
      end)
    end

    @tag listen_storage: true
    test "saves new last execution time in storage", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})
        now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
        TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

        assert_receive {:update_last_execution_date, {TestScheduler, %NaiveDateTime{}}, _},
                       @max_timeout

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
      end)
    end

    test "normal schedule in other timezone triggers once per second", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)
        |> Job.set_timezone("Europe/Zurich")

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        spawn(fn ->
          now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
          add1 = NaiveDateTime.add(now, 1, :second)
          TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})
          Process.sleep(1_000)
          TestProducer.send(producer, %ClockEvent{time: add1, catch_up: false})
        end)

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
      end)
    end

    test "impossible schedule will not create a crash", %{producer: producer} do
      # Some schedule that will never trigger
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[1 1 1 1 1 2000])

      assert capture_log(fn ->
               TestProducer.send(producer, {:add, job})

               now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
               TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

               refute_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
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

               now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
               TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

               refute_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
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

        now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
        TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout

        TestProducer.send(producer, {:add, job_new})

        TestProducer.send(producer, %ClockEvent{
          time: NaiveDateTime.add(now, 1, :second),
          catch_up: false
        })

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
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

        now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
        TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

        assert_receive {:received, %ExecuteEvent{job: ^job_new}}, @max_timeout
      end)
    end
  end

  describe "remove" do
    test "stops triggering after remove", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})
        now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
        TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout

        TestProducer.send(producer, {:remove, job.name})

        TestProducer.send(producer, %ClockEvent{
          time: NaiveDateTime.add(now, 1, :second),
          catch_up: false
        })

        refute_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
      end)
    end

    test "remove inexistent will not crash", %{producer: producer} do
      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      capture_log(fn ->
        TestProducer.send(producer, {:add, job})

        now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
        TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout

        TestProducer.send(producer, {:remove, make_ref()})

        TestProducer.send(producer, %ClockEvent{
          time: NaiveDateTime.add(now, 1, :second),
          catch_up: false
        })

        assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
      end)
    end
  end

  describe "swarm/handoff" do
    @tag manual_dispatch: true
    test "works" do
      Process.flag(:trap_exit, true)
      now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

      {:ok, producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, Old),
          job_broadcaster_reference: producer,
          clock_broadcaster_reference: producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(producer, {:add, job})

      TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

      assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, New),
          job_broadcaster_reference: producer,
          clock_broadcaster_reference: producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, new_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_broadcaster, self())

      HandoffHelper.initiate_handoff(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      TestProducer.send(producer, %ClockEvent{
        time: NaiveDateTime.add(now, 1, :second),
        catch_up: false
      })

      assert_receive {:received, %ExecuteEvent{job: ^job}}, @max_timeout
    end

    @tag manual_dispatch: true
    test "works empty" do
      Process.flag(:trap_exit, true)

      now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

      {:ok, producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, Old),
          job_broadcaster_reference: producer,
          clock_broadcaster_reference: producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, New),
          job_broadcaster_reference: producer,
          clock_broadcaster_reference: producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, new_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _new_consumer} = TestConsumer.start_link(new_broadcaster, self())

      HandoffHelper.initiate_handoff(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      job =
        TestScheduler.new_job()
        |> Job.set_schedule(~e[*]e)

      TestProducer.send(producer, {:add, job})

      TestProducer.send(producer, %ClockEvent{time: now, catch_up: false})

      assert_receive {:received, %ExecuteEvent{job: ^job}}, @init_timeout
    end
  end

  describe "swarm/resolve_conflict" do
    @tag manual_dispatch: true
    test "works" do
      Process.flag(:trap_exit, true)

      now = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

      {:ok, old_producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, Old),
          job_broadcaster_reference: old_producer,
          clock_broadcaster_reference: old_producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

      {:ok, old_broadcaster} = apply(ExecutionBroadcaster, f, a)

      {:ok, _old_consumer} = TestConsumer.start_link(old_broadcaster, self())

      {:ok, new_producer} = TestProducer.start_link()

      %{start: {ExecutionBroadcaster, f, a}} =
        ExecutionBroadcaster.child_spec(%StartOpts{
          name: Module.concat(__MODULE__, New),
          job_broadcaster_reference: new_producer,
          clock_broadcaster_reference: new_producer,
          storage: TestStorage,
          scheduler: TestScheduler,
          debug_logging: true
        })

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

      TestProducer.send(old_producer, %ClockEvent{time: now, catch_up: false})
      TestProducer.send(new_producer, %ClockEvent{time: now, catch_up: false})

      assert_receive {:received, %ExecuteEvent{job: ^old_job}}, @max_timeout
      assert_receive {:received, %ExecuteEvent{job: ^new_job}}, @max_timeout

      HandoffHelper.resolve_conflict(old_broadcaster, new_broadcaster)

      assert_receive {:EXIT, ^old_broadcaster, :shutdown}

      TestProducer.send(old_producer, %ClockEvent{
        time: NaiveDateTime.add(now, 1, :second),
        catch_up: false
      })

      TestProducer.send(new_producer, %ClockEvent{
        time: NaiveDateTime.add(now, 1, :second),
        catch_up: false
      })

      assert_receive {:received, %ExecuteEvent{job: ^old_job}}, @max_timeout
      assert_receive {:received, %ExecuteEvent{job: ^new_job}}, @max_timeout
    end
  end
end
