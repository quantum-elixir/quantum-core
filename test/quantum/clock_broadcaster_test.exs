defmodule Quantum.ClockBroadcasterTest do
  @moduledoc false

  use ExUnit.Case

  alias Quantum.ClockBroadcaster
  alias Quantum.ClockBroadcaster.Event
  alias Quantum.ClockBroadcaster.StartOpts

  @listen_events 10

  defmodule TestScheduler do
    @moduledoc false

    use Quantum, otp_app: :quantum
  end

  defmodule StoredClock do
    use Quantum.Storage.Test

    @impl Quantum.Storage
    def last_execution_date(pid), do: Agent.get(pid, & &1)
  end

  for {shape, offset} <- [{:datetime, -30}, {:naive, -30}, {:datetime, 0}] do
    test "resumes after stored #{shape} at offset #{offset}", %{test: test} do
      time = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(unquote(offset))
      stored = if unquote(shape) == :naive, do: DateTime.to_naive(time), else: time
      start_supervised!(%{
        id: StoredClock,
        start: {Agent, :start_link, [fn -> stored end, [name: TestScheduler.Storage]]}
      })

      stream = stream_broadcaster!(test, storage: StoredClock, scheduler: TestScheduler)
      next = DateTime.add(time, 1, :second)
      assert [%Event{time: ^next} = event] = Enum.take(stream, 1)
      if unquote(offset) < 0, do: assert(event.catch_up)
    end
  end

  test "should only generate event from event struct", %{test: test} do
    events =
      test
      |> stream_broadcaster!()
      |> Stream.take(1)
      |> Enum.to_list()

    assert [%Event{}] = events
  end

  test "should only generate event every second", %{test: test} do
    self = self()

    test
    |> stream_broadcaster!()
    |> Stream.take(@listen_events)
    |> Stream.each(fn event ->
      send(self, {:event, event, DateTime.utc_now()})
    end)
    |> Enum.to_list()

    for _ <- 1..@listen_events do
      assert_received {:event, _, _} = message

      assert_live_event(message)
    end
  end

  test "catches up fast and then one every second", %{test: test} do
    self = self()

    start_time = DateTime.add(DateTime.utc_now(), -@listen_events, :second)

    test
    |> stream_broadcaster!(start_time: start_time)
    |> Stream.take(@listen_events + 1)
    |> Stream.each(&receive_send(self, &1))
    |> Enum.to_list()

    for _ <- 1..@listen_events do
      assert_received {:event, _, _} = message

      assert_catch_up_event(message)
    end

    assert_received {:event, _, _} = message

    assert_live_event(message)
  end

  test "should wait for future date until", %{test: test} do
    self = self()

    start_time = DateTime.add(DateTime.utc_now(), 2, :second)

    test
    |> stream_broadcaster!(start_time: start_time)
    |> Stream.take(@listen_events)
    |> Stream.each(&receive_send(self, &1))
    |> Enum.to_list()

    for _ <- 1..@listen_events do
      assert_received {:event, _, _} = message

      assert_live_event(message)
    end
  end

  defp receive_send(pid, event) do
    send(pid, {:event, event, DateTime.utc_now()})
  end

  defp assert_live_event(message) do
    assert {:event,
            %Event{
              time:
                %DateTime{
                  year: year,
                  month: month,
                  day: day,
                  hour: hour,
                  minute: minute,
                  second: second
                } = event_time,
              catch_up: false
            },
            %DateTime{
              year: year,
              month: month,
              day: day,
              hour: hour,
              minute: minute,
              second: second
            } = receive_time} = message

    assert DateTime.diff(event_time, receive_time, :millisecond) < 100
  end

  defp assert_catch_up_event(message) do
    assert {:event,
            %Event{
              catch_up: true
            }, _} = message
  end

  defp start_broadcaster!(test, opts) do
    start_supervised!(
      {ClockBroadcaster,
       struct!(
         StartOpts,
         Keyword.merge(
           [
             name: Module.concat(__MODULE__, test),
             debug_logging: false,
             start_time: DateTime.utc_now(),
             storage: Quantum.Storage.Test,
             scheduler: NotNeeded
           ],
           Enum.to_list(opts)
         )
       )}
    )
  end

  defp stream_broadcaster!(test, opts \\ %{}) do
    GenStage.stream([{start_broadcaster!(test, opts), max_demand: 1000}])
  end
end
