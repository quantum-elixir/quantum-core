defmodule Quantum.ClockBroadcaster do
  @moduledoc false

  # Broadcasts the time to run jobs for

  use GenStage

  require Logger

  alias __MODULE__.{Event, InitOpts, StartOpts, State}

  @spec start_link(opts :: StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    __MODULE__
    |> GenStage.start_link(
      struct!(InitOpts, Map.take(opts, [:start_time, :storage, :scheduler, :debug_logging])),
      name: name
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.monitor(pid)
        {:ok, pid}

      {:error, _reason} = error ->
        error
    end
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
      |> NaiveDateTime.truncate(:second)
      # Roll back one second since handle_tick will start at `now + 1`.
      |> NaiveDateTime.add(-1, :second)

    :timer.send_interval(1000, :tick)

    {:producer,
     %State{
       time: start_time,
       debug_logging: debug_logging,
       remaining_demand: 0
     }}
  end

  @impl GenStage
  def handle_demand(demand, %State{remaining_demand: remaining_demand} = state) do
    handle_tick(%State{state | remaining_demand: remaining_demand + demand})
  end

  @impl GenStage
  def handle_info(:tick, state) do
    handle_tick(state)
  end

  def handle_info(_message, state) do
    {:noreply, [], state}
  end

  defp handle_tick(%State{remaining_demand: 0} = state) do
    {:noreply, [], state}
  end

  defp handle_tick(%State{remaining_demand: remaining_demand, time: time} = state)
       when remaining_demand > 0 do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    {events, new_time} =
      Enum.reduce_while(
        1..remaining_demand,
        {[], time},
        fn _, {list, time} = acc ->
          new_time = NaiveDateTime.add(time, 1, :second)

          case NaiveDateTime.compare(new_time, now) do
            :lt ->
              {:cont, {[%Event{time: new_time, catch_up: true} | list], new_time}}

            :eq ->
              {:cont, {[%Event{time: new_time, catch_up: false} | list], new_time}}

            :gt ->
              {:halt, acc}
          end
        end
      )

    events = Enum.reverse(events)

    new_remaining_demand = remaining_demand - Enum.count(events)

    if remaining_demand > 0 and new_remaining_demand == 0 do
      log_caught_up(state)
    end

    {:noreply, events, %State{state | time: new_time, remaining_demand: new_remaining_demand}}
  end

  defp log_caught_up(%State{debug_logging: false}), do: :ok

  defp log_caught_up(%State{debug_logging: true}),
    do:
      Logger.debug(fn ->
        {"Clock Producer caught up with past times and is now running in normal time",
         node: Node.self()}
      end)
end
