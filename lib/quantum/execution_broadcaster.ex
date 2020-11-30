defmodule Quantum.ExecutionBroadcaster do
  @moduledoc false

  # Receives Added / Removed Jobs, Broadcasts Executions of Jobs

  use GenStage

  require Logger

  alias Crontab.CronExpression
  alias Crontab.Scheduler, as: CrontabScheduler

  alias Quantum.ClockBroadcaster.Event, as: ClockEvent

  alias Quantum.{
    DateLibrary,
    DateLibrary.InvalidDateTimeForTimezoneError,
    DateLibrary.InvalidTimezoneError
  }

  alias Quantum.ExecutionBroadcaster.Event, as: ExecuteEvent
  alias Quantum.ExecutionBroadcaster.InitOpts
  alias Quantum.ExecutionBroadcaster.State
  alias Quantum.Job

  alias __MODULE__.{InitOpts, StartOpts, State}

  @type event :: {:add, Job.t()} | {:execute, Job.t()}

  defmodule JobInPastError do
    @moduledoc false
    defexception message:
                   "The job was scheduled in the past. This must not happen to prevent infinite loops!"
  end

  # Start Stage
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    __MODULE__
    |> GenStage.start_link(
      struct!(
        InitOpts,
        Map.take(opts, [
          :job_broadcaster_reference,
          :clock_broadcaster_reference,
          :storage,
          :scheduler,
          :debug_logging
        ])
      ),
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
  def init(%InitOpts{
        job_broadcaster_reference: job_broadcaster,
        clock_broadcaster_reference: clock_broadcaster,
        storage: storage,
        scheduler: scheduler,
        debug_logging: debug_logging
      }) do
    storage_pid = GenServer.whereis(Module.concat(scheduler, Storage))

    {:producer_consumer,
     %State{
       uninitialized_jobs: [],
       execution_timeline: [],
       storage: storage,
       storage_pid: storage_pid,
       scheduler: scheduler,
       debug_logging: debug_logging
     }, subscribe_to: [job_broadcaster, clock_broadcaster]}
  end

  @impl GenStage
  def handle_events(events, _, state) do
    {events, state} =
      Enum.reduce(events, {[], state}, fn event, {list, state} ->
        {new_events, state} = handle_event(event, state)
        {list ++ new_events, state}
      end)

    {:noreply, events, state}
  end

  def handle_event(
        {:add, %Job{schedule: %CronExpression{reboot: true}, name: name} = job},
        %State{uninitialized_jobs: uninitialized_jobs, debug_logging: debug_logging} = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Scheduling job for single reboot execution", node: Node.self(), name: name}
      end)

    {[%ExecuteEvent{job: job}], %{state | uninitialized_jobs: [job | uninitialized_jobs]}}
  end

  def handle_event(
        {:add, %Job{name: name} = job},
        %State{uninitialized_jobs: uninitialized_jobs, debug_logging: debug_logging} = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Adding job", node: Node.self(), name: name}
      end)

    {[], %{state | uninitialized_jobs: [job | uninitialized_jobs]}}
  end

  def handle_event(
        {:run, %Job{name: name} = job},
        %State{debug_logging: debug_logging} = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Running job once", node: Node.self(), name: name}
      end)

    {[%ExecuteEvent{job: job}], state}
  end

  def handle_event(
        {:remove, name},
        %State{
          uninitialized_jobs: uninitialized_jobs,
          execution_timeline: execution_timeline,
          debug_logging: debug_logging
        } = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Removing job", node: Node.self(), name: name}
      end)

    uninitialized_jobs = Enum.reject(uninitialized_jobs, &(&1.name == name))

    execution_timeline =
      execution_timeline
      |> Enum.map(fn {date, job_list} ->
        {date, Enum.reject(job_list, &match?(%Job{name: ^name}, &1))}
      end)
      |> Enum.reject(fn
        {_, []} -> true
        {_, _} -> false
      end)

    {[],
     %{state | uninitialized_jobs: uninitialized_jobs, execution_timeline: execution_timeline}}
  end

  def handle_event(
        %ClockEvent{time: time},
        state
      ) do
    state
    |> initialize_jobs(time)
    |> execute_events_to_fire(time)
  end

  @impl GenStage
  def handle_info(_message, state) do
    {:noreply, [], state}
  end

  defp initialize_jobs(%State{uninitialized_jobs: uninitialized_jobs} = state, time) do
    uninitialized_jobs
    |> Enum.reject(&match?(%Job{schedule: %CronExpression{reboot: true}}, &1))
    |> Enum.reduce(
      %{
        state
        | uninitialized_jobs:
            Enum.filter(
              uninitialized_jobs,
              &match?(%Job{schedule: %CronExpression{reboot: true}}, &1)
            )
      },
      &add_job_to_state(&1, &2, time)
    )
    |> sort_state
  end

  defp execute_events_to_fire(%State{execution_timeline: []} = state, _time), do: {[], state}

  defp execute_events_to_fire(
         %State{
           storage: storage,
           storage_pid: storage_pid,
           debug_logging: debug_logging,
           execution_timeline: [{time_to_execute, jobs} | tail]
         } = state,
         time
       ) do
    case NaiveDateTime.compare(time, time_to_execute) do
      :gt ->
        raise "Jobs were skipped"

      :lt ->
        {[], state}

      :eq ->
        :ok = storage.update_last_execution_date(storage_pid, time_to_execute)

        events =
          for %Job{name: job_name} = job <- jobs do
            debug_logging &&
              Logger.debug(fn ->
                {"Scheduling job for execution", node: Node.self(), name: job_name}
              end)

            %ExecuteEvent{job: job}
          end

        {next_events, new_state} =
          jobs
          |> Enum.reduce(
            %{state | execution_timeline: tail},
            &add_job_to_state(&1, &2, NaiveDateTime.add(time, 1, :second))
          )
          |> sort_state
          |> execute_events_to_fire(time)

        {events ++ next_events, new_state}
    end
  end

  defp add_job_to_state(
         %Job{schedule: schedule, timezone: timezone, name: name} = job,
         state,
         time
       ) do
    job
    |> get_next_execution_time(time)
    |> case do
      {:ok, date} ->
        add_to_state(state, time, date, job)

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

      state
  end

  defp get_next_execution_time(
         %Job{schedule: schedule, timezone: timezone, name: name} = job,
         time
       ) do
    schedule
    |> CrontabScheduler.get_next_run_date(DateLibrary.to_tz!(time, timezone))
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

  defp sort_state(%State{execution_timeline: execution_timeline} = state) do
    %{
      state
      | execution_timeline:
          Enum.sort_by(execution_timeline, fn {date, _} -> NaiveDateTime.to_erl(date) end)
    }
  end

  defp add_to_state(%State{execution_timeline: execution_timeline} = state, time, date, job) do
    unless NaiveDateTime.compare(time, date) in [:lt, :eq] do
      raise Quantum.ExecutionBroadcaster.JobInPastError
    end

    %{state | execution_timeline: add_job_at_date(execution_timeline, date, job)}
  end

  defp add_job_at_date(execution_timeline, date, job) do
    case find_date_and_put_job(execution_timeline, date, job) do
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
end
