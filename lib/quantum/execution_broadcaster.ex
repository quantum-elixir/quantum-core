defmodule Quantum.ExecutionBroadcaster do
  @moduledoc """
  Receives Added / Removed Jobs, Broadcasts Executions of Jobs
  """

  use GenStage

  require Logger

  alias Quantum.{Job, Util, DateLibrary}
  alias Crontab.{Scheduler, CronExpression}
  alias Quantum.DateLibrary.{InvalidDateTimeForTimezoneError, InvalidTimezoneError}

  defmodule JobInPastError do
    defexception message:
                   "The job was scheduled in the past. This must not happen to prevent infinite loops!"
  end

  @doc """
  Start Stage

  ### Arguments

    * `name` - The name of the stage
    * `job_broadcaster` - The name of the stage to listen to

  """
  @spec start_link(GenServer.server(), GenServer.server()) :: GenServer.on_start()
  def start_link(name, job_broadcaster) do
    __MODULE__
    |> GenStage.start_link(job_broadcaster, name: name)
    |> Util.start_or_link()
  end

  @doc false
  @spec child_spec({GenServer.server(), GenServer.server()}) :: Supervisor.child_spec()
  def child_spec({name, job_broadcaster}) do
    %{super([]) | start: {__MODULE__, :start_link, [name, job_broadcaster]}}
  end

  @doc false
  def init(job_broadcaster) do
    state = %{jobs: [], time: NaiveDateTime.utc_now(), timer: nil}
    {:producer_consumer, state, subscribe_to: [job_broadcaster]}
  end

  def handle_events(events, _, state) do
    reboot_add_events =
      events
      |> Enum.filter(&add_reboot_event?/1)
      |> Enum.map(fn {:add, job} -> {:execute, job} end)

    for {_, %{name: job_name}} <- reboot_add_events do
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Scheduling job for single reboot execution: #{
          inspect(job_name)
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

  def handle_info(:execute, %{jobs: [{time_to_execute, jobs_to_execute} | tail]} = state) do
    state =
      state
      |> Map.put(:timer, nil)
      |> Map.put(:jobs, tail)
      |> Map.put(:time, NaiveDateTime.add(time_to_execute, 1, :second))

    state =
      jobs_to_execute
      |> (fn jobs ->
            for %{name: job_name} <- jobs do
              Logger.debug(fn ->
                "[#{inspect(Node.self())}][#{__MODULE__}] Scheduling job for execution #{
                  inspect(job_name)
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

  defp handle_event({:add, %{name: job_name} = job}, state) do
    Logger.debug(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job_name)}"
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
        {date, Enum.reject(job_list, &match?(%{name: ^name}, &1))}
      end)
      |> Enum.reject(fn
        {_, []} -> true
        {_, _} -> false
      end)

    %{state | jobs: jobs}
  end

  defp add_job_to_state(
         %Job{schedule: schedule, timezone: timezone, name: name} = job,
         %{time: time} = state
       ) do
    job
    |> get_next_execution_time(time)
    |> case do
      {:ok, date} ->
        add_to_state(state, date, job)

      {:error, _} ->
        Logger.warn(fn ->
          """
          Invalid Schedule #{inspect(schedule)} provided for job #{inspect(name)}.
          No matching dates found. The job was removed.
          """
        end)

        state
    end
  rescue
    e in InvalidTimezoneError ->
      Logger.error(
        "Invalid Timezone #{inspect(timezone)} provided for job #{inspect(name)}.",
        job: job,
        error: e
      )
  end

  defp get_next_execution_time(
         %Job{schedule: schedule, timezone: timezone, name: name} = job,
         time
       ) do
    schedule
    |> Scheduler.get_next_run_date(DateLibrary.to_tz!(time, timezone))
    |> case do
      {:ok, date} ->
        {:ok, DateLibrary.to_utc!(date, timezone)}

      {:error, _} = error ->
        error
    end
  rescue
    _ in InvalidDateTimeForTimezoneError ->
      next_time = NaiveDateTime.add(time, 60, :second)

      Logger.warn(fn ->
        """
        Next execution time for job #{inspect(name)} is not a valid time.
        Retrying with #{inspect(next_time)}
        """
      end)

      get_next_execution_time(job, next_time)
  end

  defp sort_state(%{jobs: jobs} = state) do
    %{state | jobs: Enum.sort_by(jobs, fn {date, _} -> NaiveDateTime.to_erl(date) end)}
  end

  defp add_to_state(%{jobs: jobs, time: time} = state, date, job) do
    unless NaiveDateTime.compare(time, date) in [:lt, :eq] do
      raise JobInPastError
    end

    %{state | jobs: add_job_at_date(jobs, date, job)}
  end

  defp add_job_at_date(jobs, date, job) do
    case find_date_and_put_job(jobs, date, job) do
      {:found, list} -> list
      {:not_found, list} -> [{date, [job]} | list]
    end
  end

  defp find_date_and_put_job([{date, jobs} | rest], date, job) do
    {:found, [{date, [job | jobs]} | rest]}
  end

  defp find_date_and_put_job([], _, _) do
    {:not_found, []}
  end

  defp find_date_and_put_job([head | rest], date, job) do
    {state, new_rest} = find_date_and_put_job(rest, date, job)
    {state, [head | new_rest]}
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
        :gt ->
          monotonic_time =
            run_date
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.to_unix(:millisecond)
            |> Kernel.-(System.time_offset(:millisecond))

          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Continuing Execution Broadcasting at #{
              inspect(monotonic_time)
            } (#{NaiveDateTime.to_iso8601(run_date)})"
          end)

          Process.send_after(self(), :execute, monotonic_time, abs: true)

        _ ->
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Continuing Execution Broadcasting ASAP (#{
              NaiveDateTime.to_iso8601(run_date)
            })"
          end)

          send(self(), :execute)
          nil
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
