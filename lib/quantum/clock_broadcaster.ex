defmodule Quantum.ClockBroadcaster do
  @moduledoc false

  # Broadcasts the time to run jobs for

  use GenStage

  require Logger

  alias __MODULE__.{Event, InitOpts, StartOpts, State}

  @spec start_link(opts :: StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    GenStage.start_link(
      __MODULE__,
      struct!(InitOpts, Map.take(opts, [:start_time, :storage, :scheduler, :debug_logging])),
      name: name
    )
  end

  @impl GenStage
  @spec init(opts :: InitOpts.t()) :: {:producer, State.t()}
  def init(%InitOpts{
        debug_logging: debug_logging,
        storage: storage,
        scheduler: scheduler,
        start_time: start_time
      }) do
    start_time =
      scheduler
      |> Module.concat(Storage)
      |> GenServer.whereis()
      |> storage.last_execution_date()
      |> case do
        :unknown -> start_time
        date -> date
      end

    {:producer,
     %State{
       time: %{start_time | microsecond: {0, 0}},
       debug_logging: debug_logging,
       remaining_demand: 0,
       timer: nil
     }}
  end

  @impl GenStage
  def handle_demand(
        demand,
        %State{remaining_demand: remaining_demand, time: time, timer: nil} = state
      )
      when demand > 0 do
    expected_event_count = demand + remaining_demand

    now = NaiveDateTime.utc_now()

    {events, new_time} =
      Enum.reduce_while(
        1..expected_event_count,
        {[], time},
        fn _, {list, time} = acc ->
          new_time = NaiveDateTime.add(time, 1, :second)

          case NaiveDateTime.compare(new_time, now) do
            :lt ->
              {:cont, {[%Event{time: new_time, catch_up: true} | list], new_time}}

            _ ->
              {:halt, acc}
          end
        end
      )

    new_remaining_demand = expected_event_count - Enum.count(events)

    if remaining_demand > 0 and new_remaining_demand == 0 do
      log_catched_up(state)
    end

    new_timer =
      if new_remaining_demand > 0 do
        schedule_next_event_timer(new_time, now)
      end

    {:noreply, events,
     %{state | time: new_time, remaining_demand: new_remaining_demand, timer: new_timer}}
  end

  def handle_demand(demand, %State{timer: timer} = state) do
    Process.cancel_timer(timer)
    handle_demand(demand, %{state | timer: nil})
  end

  @impl GenStage
  def handle_info(:ping, %State{remaining_demand: 0} = state) do
    {:noreply, [], state}
  end

  def handle_info(:ping, %State{time: time, remaining_demand: remaining_demand} = state)
      when remaining_demand > 0 do
    now = NaiveDateTime.utc_now()
    new_time = NaiveDateTime.add(time, 1, :second)

    case NaiveDateTime.compare(new_time, now) do
      :lt ->
        timer = schedule_next_event_timer(new_time, now)

        {:noreply, [%Event{time: new_time, catch_up: false}],
         %{state | time: new_time, timer: timer}}

      _ ->
        warn_event_too_early()

        timer = schedule_next_event_timer(time, now)

        {:noreply, [], %{state | timer: timer}}
    end
  end

  defp schedule_next_event_timer(time, now) do
    next_event_diff =
      %{time | microsecond: {0, 0}}
      |> NaiveDateTime.add(1, :second)
      |> NaiveDateTime.diff(now, :millisecond)

    next_event_diff =
      if next_event_diff < 0 do
        0
      else
        next_event_diff
      end

    Process.send_after(self(), :ping, next_event_diff)
  end

  defp log_catched_up(%State{debug_logging: false}), do: :ok

  defp log_catched_up(%State{debug_logging: true}),
    do:
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Clock Producer catched up with past times and is now running in normal time"
      end)

  defp warn_event_too_early,
    do:
      Logger.warn(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Clock Producer received a too early ping event, rescheduling"
      end)
end
