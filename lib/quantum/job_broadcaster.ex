defmodule Quantum.JobBroadcaster do
  @moduledoc """
  This Module is here to broadcast added / removed tabs into the execution pipeline.
  """

  use GenStage

  require Logger

  alias Quantum.{Job, Scheduler}
  alias Quantum.Storage.Adapter
  alias __MODULE__.{InitOpts, StartOpts, State}

  @type event :: {:add, Job.t()} | {:remove, Job.t()}

  @doc """
  Start Job Broadcaster
  """
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    GenStage.start_link(
      __MODULE__,
      struct!(InitOpts, Map.take(opts, [:jobs, :storage, :scheduler, :debug_logging])),
      name: name
    )
  end

  @spec start_link(GenServer.server(), [Job.t()], Adapter, Scheduler, boolean()) ::
          GenServer.on_start()
  def start_link(name, jobs, storage, scheduler, debug_logging) do
    start_link(%StartOpts{
      name: name,
      jobs: jobs,
      storage: storage,
      scheduler: scheduler,
      debug_logging: debug_logging
    })
  end

  @doc false
  @spec child_spec(StartOpts.t()) :: Supervisor.child_spec()
  def child_spec(%StartOpts{} = opts), do: super(opts)

  @spec child_spec({Keyword.t() | GenServer.server(), [Job.t()], Adapter, Scheduler, boolean()}) ::
          Supervisor.child_spec()
  def child_spec({name, jobs, storage, scheduler, debug_logging}),
    do:
      child_spec(%StartOpts{
        name: name,
        jobs: jobs,
        storage: storage,
        scheduler: scheduler,
        debug_logging: debug_logging
      })

  @doc false
  def init(%InitOpts{
        jobs: jobs,
        storage: storage,
        scheduler: scheduler,
        debug_logging: debug_logging
      }) do
    effective_jobs =
      scheduler
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

          storage_jobs
      end

    {:producer,
     %State{
       jobs: Enum.into(effective_jobs, %{}, fn %{name: name} = job -> {name, job} end),
       buffer: for(%{state: :active} = job <- effective_jobs, do: {:add, job}),
       storage: storage,
       scheduler: scheduler,
       debug_logging: debug_logging
     }}
  end

  def handle_demand(demand, %State{buffer: buffer} = state) do
    {to_send, remaining} = Enum.split(buffer, demand)

    {:noreply, to_send, %{state | buffer: remaining}}
  end

  def handle_cast(
        {:add, %Job{state: :active, name: job_name} = job},
        %State{jobs: jobs, storage: storage, scheduler: scheduler, debug_logging: debug_logging} =
          state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job_name)}"
      end)

    :ok = storage.add_job(scheduler, job)

    {:noreply, [{:add, job}], %{state | jobs: Map.put(jobs, job_name, job)}}
  end

  def handle_cast(
        {:add, %Job{state: :inactive, name: job_name} = job},
        %State{jobs: jobs, storage: storage, scheduler: scheduler, debug_logging: debug_logging} =
          state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Adding job #{inspect(job_name)}"
      end)

    :ok = storage.add_job(scheduler, job)

    {:noreply, [], %{state | jobs: Map.put(jobs, job_name, job)}}
  end

  def handle_cast(
        {:delete, name},
        %State{jobs: jobs, storage: storage, scheduler: scheduler, debug_logging: debug_logging} =
          state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Deleting job #{inspect(name)}"
      end)

    case Map.fetch(jobs, name) do
      {:ok, %{state: :active}} ->
        :ok = storage.delete_job(scheduler, name)

        {:noreply, [{:remove, name}], %{state | jobs: Map.delete(jobs, name)}}

      {:ok, %{state: :inactive}} ->
        :ok = storage.delete_job(scheduler, name)

        {:noreply, [], %{state | jobs: Map.delete(jobs, name)}}

      :error ->
        {:noreply, [], state}
    end
  end

  def handle_cast(
        {:change_state, name, new_state},
        %State{jobs: jobs, storage: storage, scheduler: scheduler, debug_logging: debug_logging} =
          state
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
        jobs = Map.update!(jobs, name, &Job.set_state(&1, new_state))

        :ok = storage.update_job_state(scheduler, job.name, new_state)

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
        %State{jobs: jobs, storage: storage, scheduler: scheduler, debug_logging: debug_logging} =
          state
      ) do
    debug_logging &&
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Deleting all jobs"
      end)

    messages = for {name, %Job{state: :active}} <- jobs, do: {:remove, name}

    :ok = storage.purge(scheduler)

    {:noreply, messages, %{state | jobs: %{}}}
  end

  def handle_cast(
        {:swarm, :end_handoff, {handoff_jobs, handoff_buffer}},
        %State{
          jobs: jobs,
          buffer: buffer
        } = state
      ) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Incorperating state from other cluster node"
    end)

    new_jobs = Enum.into(handoff_jobs, jobs)
    {:noreply, [], %{state | jobs: new_jobs, buffer: buffer ++ handoff_buffer}}
  end

  def handle_cast(
        {:swarm, :resolve_conflict, {handoff_jobs, handoff_buffer}},
        %State{
          jobs: jobs,
          buffer: buffer
        } = state
      ) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Incorperating conflict state from other cluster node"
    end)

    new_jobs = Enum.into(handoff_jobs, jobs)
    {:noreply, [], %{state | jobs: new_jobs, buffer: buffer ++ handoff_buffer}}
  end

  def handle_call(:jobs, _, %State{jobs: jobs} = state),
    do: {:reply, Map.to_list(jobs), [], state}

  def handle_call({:find_job, name}, _, %State{jobs: jobs} = state),
    do: {:reply, Map.get(jobs, name), [], state}

  def handle_call({:swarm, :begin_handoff}, _from, %State{jobs: jobs, buffer: buffer} = state) do
    Logger.info(fn ->
      "[#{inspect(Node.self())}][#{__MODULE__}] Handing of state to other cluster node"
    end)

    {:reply, {:resume, {jobs, buffer}}, [], state}
  end

  def handle_info({:swarm, :die}, state) do
    {:stop, :shutdown, state}
  end
end
