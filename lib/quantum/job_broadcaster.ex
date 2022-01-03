defmodule Quantum.JobBroadcaster do
  @moduledoc false

  # This Module is here to broadcast added / removed tabs into the execution pipeline.

  use GenStage

  require Logger

  alias Quantum.Job
  alias __MODULE__.{InitOpts, StartOpts, State}

  @type event :: {:add, Job.t()} | {:remove, Job.t()}

  # Start Job Broadcaster
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    __MODULE__
    |> GenStage.start_link(
      struct!(InitOpts, Map.take(opts, [:jobs, :storage, :scheduler, :debug_logging])),
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
        jobs: jobs,
        storage: storage,
        scheduler: scheduler,
        debug_logging: debug_logging
      }) do
    storage_pid = GenServer.whereis(Module.concat(scheduler, Storage))

    effective_jobs =
      storage_pid
      |> storage.jobs()
      |> case do
        :not_applicable ->
          debug_logging &&
            Logger.debug(fn ->
              {"Loading Initial Jobs from Config", node: Node.self()}
            end)

          jobs

        storage_jobs when is_list(storage_jobs) ->
          debug_logging &&
            Logger.debug(fn ->
              {"Loading Initial Jobs from Storage, skipping config", node: Node.self()}
            end)

          for %Job{state: :active} = job <- storage_jobs do
            # Send event to telemetry in case the end user wants to monitor events
            :telemetry.execute([:quantum, :job, :add], %{}, %{
              job: job,
              scheduler: scheduler
            })
          end

          storage_jobs
      end

    {:producer,
     %State{
       jobs: effective_jobs |> Enum.map(&{&1.name, &1}) |> Map.new(),
       buffer: for(%{state: :active} = job <- effective_jobs, do: {:add, job}),
       storage: storage,
       storage_pid: storage_pid,
       scheduler: scheduler,
       debug_logging: debug_logging
     }}
  end

  @impl GenStage
  def handle_demand(demand, %State{buffer: buffer} = state) do
    {to_send, remaining} = Enum.split(buffer, demand)

    {:noreply, to_send, %{state | buffer: remaining}}
  end

  @impl GenStage

  def handle_cast(
        {:add, %Job{state: :active, name: job_name} = job},
        %State{
          jobs: jobs,
          storage: storage,
          storage_pid: storage_pid,
          debug_logging: debug_logging
        } = state
      ) do
    case jobs do
      %{^job_name => %Job{state: :active} = old_job} ->
        debug_logging &&
          Logger.debug(fn ->
            {"Replacing job", node: Node.self(), name: job_name}
          end)

        :ok = update_job(storage, storage_pid, job, state.scheduler)

        {:noreply, [{:remove, old_job}, {:add, job}],
         %{state | jobs: Map.put(jobs, job_name, job)}}

      %{^job_name => %Job{state: :inactive}} ->
        debug_logging &&
          Logger.debug(fn ->
            {"Replacing job", node: Node.self(), name: job_name}
          end)

        :ok = update_job(storage, storage_pid, job, state.scheduler)

        {:noreply, [{:add, job}], %{state | jobs: Map.put(jobs, job_name, job)}}

      _ ->
        debug_logging &&
          Logger.debug(fn ->
            {"Adding job", node: Node.self(), name: job_name}
          end)

        # Send event to telemetry in case the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job: job,
          scheduler: state.scheduler
        })

        :ok = storage.add_job(storage_pid, job)

        {:noreply, [{:add, job}], %{state | jobs: Map.put(jobs, job_name, job)}}
    end
  end

  def handle_cast(
        {:add, %Job{state: :inactive, name: job_name} = job},
        %State{
          jobs: jobs,
          storage: storage,
          storage_pid: storage_pid,
          debug_logging: debug_logging
        } = state
      ) do
    case jobs do
      %{^job_name => %Job{state: :active} = old_job} ->
        debug_logging &&
          Logger.debug(fn ->
            {"Replacing job", node: Node.self(), name: job_name}
          end)

        :ok = update_job(storage, storage_pid, job, state.scheduler)

        {:noreply, [{:remove, old_job}], %{state | jobs: Map.put(jobs, job_name, job)}}

      %{^job_name => %Job{state: :inactive}} ->
        debug_logging &&
          Logger.debug(fn ->
            {"Replacing job", node: Node.self(), name: job_name}
          end)

        :ok = update_job(storage, storage_pid, job, state.scheduler)

        {:noreply, [], %{state | jobs: Map.put(jobs, job_name, job)}}

      _ ->
        debug_logging &&
          Logger.debug(fn ->
            {"Adding job", node: Node.self(), name: job_name}
          end)

        # Send event to telemetry in case the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job: job,
          scheduler: state.scheduler
        })

        :ok = storage.add_job(storage_pid, job)

        {:noreply, [], %{state | jobs: Map.put(jobs, job_name, job)}}
    end
  end

  def handle_cast(
        {:delete, name},
        %State{
          jobs: jobs,
          storage: storage,
          storage_pid: storage_pid,
          debug_logging: debug_logging
        } = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Deleting job", node: Node.self(), name: name}
      end)

    case Map.fetch(jobs, name) do
      {:ok, %{state: :active, name: name} = job} ->
        # Send event to telemetry in case the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :delete], %{}, %{
          job: job,
          scheduler: state.scheduler
        })

        :ok = storage.delete_job(storage_pid, name)

        {:noreply, [{:remove, name}], %{state | jobs: Map.delete(jobs, name)}}

      {:ok, %{state: :inactive, name: name} = job} ->
        # Send event to telemetry in case the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :delete], %{}, %{
          job: job,
          scheduler: state.scheduler
        })

        :ok = storage.delete_job(storage_pid, name)

        {:noreply, [], %{state | jobs: Map.delete(jobs, name)}}

      :error ->
        {:noreply, [], state}
    end
  end

  def handle_cast(
        {:change_state, name, new_state},
        %State{
          jobs: jobs,
          storage: storage,
          storage_pid: storage_pid,
          debug_logging: debug_logging
        } = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Change job state", node: Node.self(), name: name}
      end)

    case Map.fetch(jobs, name) do
      :error ->
        {:noreply, [], state}

      {:ok, %{state: ^new_state}} ->
        {:noreply, [], state}

      {:ok, job} ->
        # Send event to telemetry in case the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :update], %{}, %{
          job: job,
          scheduler: state.scheduler
        })

        jobs = Map.update!(jobs, name, &Job.set_state(&1, new_state))

        :ok = storage.update_job_state(storage_pid, job.name, new_state)

        case new_state do
          :active ->
            {:noreply, [{:add, %{job | state: new_state}}], %{state | jobs: jobs}}

          :inactive ->
            {:noreply, [{:remove, name}], %{state | jobs: jobs}}
        end
    end
  end

  def handle_cast(
        {:run_job, name},
        %State{
          jobs: jobs,
          debug_logging: debug_logging
        } = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Running job once", node: Node.self(), name: name}
      end)

    case Map.fetch(jobs, name) do
      :error ->
        {:noreply, [], state}

      {:ok, job} ->
        {:noreply, [{:run, job}], state}
    end
  end

  def handle_cast(
        :delete_all,
        %State{
          jobs: jobs,
          storage: storage,
          storage_pid: storage_pid,
          debug_logging: debug_logging
        } = state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        {"Deleting all jobs", node: Node.self()}
      end)

    for {_name, %Job{} = job} <- jobs do
      # Send event to telemetry in case the end user wants to monitor events
      :telemetry.execute([:quantum, :job, :delete], %{}, %{
        job: job,
        scheduler: state.scheduler
      })
    end

    messages = for {name, %Job{state: :active}} <- jobs, do: {:remove, name}

    :ok = storage.purge(storage_pid)

    {:noreply, messages, %{state | jobs: %{}}}
  end

  @impl GenStage
  def handle_call(:jobs, _, %State{jobs: jobs} = state),
    do: {:reply, Map.to_list(jobs), [], state}

  def handle_call({:find_job, name}, _, %State{jobs: jobs} = state),
    do: {:reply, Map.get(jobs, name), [], state}

  @impl GenStage
  def handle_info(_message, state) do
    {:noreply, [], state}
  end

  defp update_job(storage, storage_pid, %Job{name: job_name} = job, scheduler) do
    # Send event to telemetry in case the end user wants to monitor events
    :telemetry.execute([:quantum, :job, :update], %{}, %{
      job: job,
      scheduler: scheduler
    })

    if function_exported?(storage, :update_job, 2) do
      :ok = storage.update_job(storage_pid, job)
    else
      :ok = storage.delete_job(storage_pid, job_name)
      :ok = storage.add_job(storage_pid, job)
    end
  end
end
