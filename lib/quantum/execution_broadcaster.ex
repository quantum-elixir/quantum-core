defmodule Quantum.ExecutionBroadcaster do
  @moduledoc """
  Receives Added / Removed Jobs, Broadcasts Executions of Jobs
  """

  use GenStage

  require Logger

  alias Quantum.{Job, Util, DateLibrary}
  alias Crontab.Scheduler, as: CrontabScheduler
  alias Crontab.CronExpression
  alias Quantum.Storage.Adapter
  alias Quantum.Scheduler

  @doc """
  Start Stage

  ### Arguments

    * `name` - The name of the stage
    * `job_broadcaster` - The name of the stage to listen to

  """
  @spec start_link(GenServer.server(), GenServer.server(), Adapter, Scheduler) ::
          GenServer.on_start()
  def start_link(name, job_broadcaster, storage, scheduler) do
    __MODULE__
    |> GenStage.start_link({job_broadcaster, storage, scheduler}, name: name)
    |> Util.start_or_link()
  end

  @doc false
  @spec child_spec({GenServer.server(), GenServer.server(), Adapter, Scheduler}) ::
          Supervisor.child_spec()
  def child_spec({name, job_broadcaster, storage, scheduler}) do
    %{super([]) | start: {__MODULE__, :start_link, [name, job_broadcaster, storage, scheduler]}}
  end

  @doc false
  def init({job_broadcaster, storage, scheduler}) do
    last_execution_date =
      case storage.last_execution_date(scheduler) do
        %NaiveDateTime{} = date ->
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Using last known execution time #{
              NaiveDateTime.to_iso8601(date)
            }"
          end)

          date

        :unknown ->
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Unknown last execution time, using now"
          end)

          NaiveDateTime.utc_now()
      end

    state = %{
      jobs: [],
      time: last_execution_date,
      timer: nil,
      storage: storage,
      scheduler: scheduler
    }

    {:producer_consumer, state, subscribe_to: [job_broadcaster]}
  end

  def handle_events(events, _, state) do
    reboot_add_events =
      events
      |> Enum.filter(&add_reboot_event?/1)
      |> Enum.map(fn {:add, job} -> {:execute, job} end)

    for {_, job} <- reboot_add_events do
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Scheduling job for single reboot execution: #{
          inspect(job.name)
        }"
      end)
    end

    state =
      events
      |> Enum.reject(&add_reboot_event?/1)
      |> Enum.reduce(state, &handle_event/2)
      |> sort_state
      |> reset_timer

    {:noreply, reboot_add_events, state}
  end

  def handle_info(
        :execute,
        %{
          jobs: [{time_to_execute, jobs_to_execute} | tail],
          storage: storage,
          scheduler: scheduler
        } = state
      ) do
    :ok = storage.update_last_execution_date(scheduler, time_to_execute)

    state =
      state
      |> Map.put(:timer, nil)
      |> Map.put(:jobs, tail)
      |> Map.put(:time, NaiveDateTime.add(time_to_execute, 1, :second))

    state =
      jobs_to_execute
      |> (fn jobs ->
            for job <- jobs do
              Logger.debug(fn ->
                "[#{inspect(Node.self())}][#{__MODULE__}] Schedluling job for execution #{
                  inspect(job.name)
                }"
              end)
            end

            jobs
          end).()
      |> Enum.reduce(state, &add_job_to_state/2)
      |> sort_state
      |> reset_timer

    {:noreply, Enum.map(jobs_to_execute, fn job -> {:execute, job} end), state}
  end

  defp handle_event({:add, job}, state) do
    Logger.debug(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job.name)}"
    end)

    add_job_to_state(job, state)
  end

  defp handle_event({:remove, name}, %{jobs: jobs} = state) do
    Logger.debug(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Removing job #{inspect(name)}"
    end)

    jobs =
      jobs
      |> Enum.map(fn {date, job_list} ->
        {date, Enum.reject(job_list, &(&1.name == name))}
      end)
      |> Enum.reject(fn
        {_, []} -> true
        {_, _} -> false
      end)

    %{state | jobs: jobs}
    |> sort_state
    |> reset_timer
  end

  defp add_job_to_state(
         %Job{schedule: schedule, timezone: timezone, name: name} = job,
         %{time: time} = state
       ) do
    case CrontabScheduler.get_next_run_date(schedule, DateLibrary.to_tz!(time, timezone)) do
      {:ok, date} ->
        add_to_state(state, DateLibrary.to_utc!(date, timezone), job)

      _ ->
        Logger.warn("""
        Invalid Schedule #{inspect(schedule)} provided for job #{inspect(name)}.
        No matching dates found. The job was removed.
        """)

        state
    end
  rescue
    error ->
      Logger.error(
        "Invalid Timezone #{inspect(timezone)} provided for job #{inspect(name)}.",
        job: job,
        error: error
      )

      state
  end

  defp sort_state(%{jobs: jobs} = state) do
    %{state | jobs: Enum.sort_by(jobs, fn {date, _} -> NaiveDateTime.to_erl(date) end)}
  end

  defp add_to_state(%{jobs: jobs} = state, date, job) do
    %{
      state
      | jobs:
          case Enum.find_index(jobs, fn {run_date, _} -> run_date == date end) do
            nil ->
              [{date, [job]} | jobs]

            index ->
              List.update_at(jobs, index, fn {run_date, old} -> {run_date, [job | old]} end)
          end
    }
  end

  defp reset_timer(%{timer: nil, jobs: []} = state) do
    state
  end

  defp reset_timer(%{timer: {timer, _}, jobs: []} = state) do
    Process.cancel_timer(timer)

    Map.put(state, :timer, nil)
  end

  defp reset_timer(%{timer: nil, jobs: jobs} = state) do
    run_date = next_run_date(jobs)

    timer =
      case NaiveDateTime.compare(run_date, NaiveDateTime.utc_now()) do
        :eq ->
          send(self(), :execute)
          nil

        _ ->
          monotonic_time =
            run_date
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.to_unix(:millisecond)
            |> Kernel.-(System.time_offset(:millisecond))

          if monotonic_time > System.monotonic_time(:millisecond) do
            Process.send_after(self(), :execute, monotonic_time, abs: true)
          else
            send(self(), :execute)
          end
      end

    Map.put(state, :timer, {timer, run_date})
  end

  defp reset_timer(%{timer: {timer, old_date}, jobs: jobs} = state) do
    run_date = next_run_date(jobs)

    case NaiveDateTime.compare(run_date, old_date) do
      :eq ->
        state

      _ ->
        Process.cancel_timer(timer)
        reset_timer(Map.put(state, :timer, nil))
    end
  end

  defp next_run_date(jobs) do
    [{run_date, _} | _rest] = jobs
    run_date
  end

  defp add_reboot_event?({:add, %Job{schedule: %CronExpression{reboot: true}}}), do: true
  defp add_reboot_event?(_), do: false
end
