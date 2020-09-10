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
              "[#{inspect(Node.self())}][#{__MODULE__}] Loading Initial Jobs from Config"
            end)

          jobs

        storage_jobs when is_list(storage_jobs) ->
          debug_logging &&
            Logger.debug(fn ->
              "[#{inspect(Node.self())}][#{__MODULE__}] Loading Initial Jobs from Storage, skipping config"
            end)

          for %Job{state: :active, name: name} = job <- storage_jobs do
            # Send event to telemetry incase the end user wants to monitor events
            :telemetry.execute([:quantum, :job, :add], %{}, %{
              job_name: name,
              job: job,
              node: inspect(Node.self()),
              module: __MODULE__,
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
            "[#{inspect(Node.self())}][#{__MODULE__}] Replacing job #{inspect(job_name)}"
          end)

        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job_name: job_name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
          scheduler: state.scheduler
        })

        :ok = storage.delete_job(storage_pid, job_name)
        :ok = storage.add_job(storage_pid, job)

        {:noreply, [{:delete, old_job}, {:add, job}],
         %{state | jobs: Map.put(jobs, job_name, job)}}

      %{^job_name => %Job{state: :inactive}} ->
        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Replacing job #{inspect(job_name)}"
          end)

        :ok = storage.delete_job(storage_pid, job_name)
        :ok = storage.add_job(storage_pid, job)

        {:noreply, [{:add, job}], %{state | jobs: Map.put(jobs, job_name, job)}}

      _ ->
        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job_name)}"
          end)

        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job_name: job_name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
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
            "[#{inspect(Node.self())}][#{__MODULE__}] Replacing job #{inspect(job_name)}"
          end)

        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job_name: job_name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
          scheduler: state.scheduler
        })

        :ok = storage.delete_job(storage_pid, job_name)
        :ok = storage.add_job(storage_pid, job)

        {:noreply, [{:delete, old_job}], %{state | jobs: Map.put(jobs, job_name, job)}}

      %{^job_name => %Job{state: :inactive}} ->
        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Replacing job #{inspect(job_name)}"
          end)

        :ok = storage.delete_job(storage_pid, job_name)
        :ok = storage.add_job(storage_pid, job)

        {:noreply, [], %{state | jobs: Map.put(jobs, job_name, job)}}

      _ ->
        debug_logging &&
          Logger.debug(fn ->
            "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job_name)}"
          end)

        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :add], %{}, %{
          job_name: job_name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
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
        "[#{inspect(Node.self())}][#{__MODULE__}] Deleting job #{inspect(name)}"
      end)

    case Map.fetch(jobs, name) do
      {:ok, %{state: :active, name: name} = job} ->
        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :delete], %{}, %{
          job_name: name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
          scheduler: state.scheduler
        })

        :ok = storage.delete_job(storage_pid, name)

        {:noreply, [{:remove, name}], %{state | jobs: Map.delete(jobs, name)}}

      {:ok, %{state: :inactive, name: name} = job} ->
        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :delete], %{}, %{
          job_name: name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
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
        "[#{inspect(Node.self())}][#{__MODULE__}] Change job state #{inspect(name)}"
      end)

    case Map.fetch(jobs, name) do
      :error ->
        {:noreply, [], state}

      {:ok, %{state: ^new_state}} ->
        {:noreply, [], state}

      {:ok, job} ->
        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :update], %{}, %{
          job_name: name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
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
        "[#{inspect(Node.self())}][#{__MODULE__}] Deleting all jobs"
      end)

    messages =
      for {name, %Job{state: :active} = job} <- jobs do
        # Send event to telemetry incase the end user wants to monitor events
        :telemetry.execute([:quantum, :job, :delete], %{}, %{
          job_name: name,
          job: job,
          node: inspect(Node.self()),
          module: __MODULE__,
          scheduler: state.scheduler
        })

        {:remove, name}
      end

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
end
