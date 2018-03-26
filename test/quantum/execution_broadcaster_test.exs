defmodule Quantum.ExecutionBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Crontab.CronExpression
  import ExUnit.CaptureLog

  alias Quantum.ExecutionBroadcaster
  alias Quantum.{TestConsumer, TestProducer}
  alias Quantum.Job

  # Allow max 10% Latency
  @max_timeout 1_100

  doctest ExecutionBroadcaster

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :execution_broadcaster_test
  end

  setup do
    {:ok, producer} = start_supervised({TestProducer, []})
    {:ok, broadcaster} = start_supervised({ExecutionBroadcaster, {__MODULE__, producer, true}})
    {:ok, _consumer} = start_supervised({TestConsumer, [broadcaster, self()]})

    {:ok, %{producer: producer, broadcaster: broadcaster, debug_logging: true}}
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
      state = %{jobs: [], time: ~N[2018-03-25 00:59:01], timer: nil, debug_logging: debug_logging}

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
end
