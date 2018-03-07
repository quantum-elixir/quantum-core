if Code.ensure_compiled?(PersistentEts) do
  defmodule Quantum.Storage.PersistentEts do
    @moduledoc """
    persistent_ets based implementation of a `Quantum.Storage.Adapter`.
    See https://hexdocs.pm/persistent_ets
    """
    require Logger
    use GenServer
    defstruct [:schedulers]

    def start_link() do
      GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    end

    #Callbacks

    defp __server__, do: __MODULE__

    def init(_) do
      {:ok, %__MODULE__{schedulers: %{}}}
    end

    def handle_call({:add_job, scheduler_module, job}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_add_job(scheduler_module, job),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:jobs, scheduler_module}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_get_jobs(scheduler_module),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:delete_job, scheduler_module, job}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_delete_job(scheduler_module, job),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:update_job_state, scheduler_module, job_name, job_state}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_update_job_state(scheduler_module, job_name, job_state),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:last_execution_date, scheduler_module}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_get_last_execution_date(scheduler_module),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:update_last_execution_date, scheduler_module, last_execution_date}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_update_last_execution_date(scheduler_module, last_execution_date),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end

    def handle_call({:purge, scheduler_module}, _from, %__MODULE__{schedulers: schedulers} = state) do
      {
        :reply,
        do_purge(scheduler_module),
        %{state|schedulers: schedulers |> Map.put_new_lazy(scheduler_module, fn -> create_scheduler_module_atom(scheduler_module) end)}
      }
    end
    # Helpers
    defp create_scheduler_module_atom(scheduler_module) do
      scheduler_module
    end

    defp job_key(job_name) do
      {:job, job_name}
    end

    defp get_ets_by_scheduler(scheduler_module) do
      scheduler_module_atom = create_scheduler_module_atom(scheduler_module)
      unless ets_exist?(scheduler_module_atom) do
        PersistentEts.new(scheduler_module_atom, "#{scheduler_module_atom}.tab", [:named_table, :set])
      else
        scheduler_module_atom
      end
    end

    defp ets_exist?(ets_name) do
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] Determining whether ETS table with name [#{inspect ets_name}] exists"
      end)
      result =
        case :ets.info(ets_name) do
          :undefined -> false
          _ -> true
        end
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] ETS table with name [#{inspect ets_name}] #{if result, do: ~S|exists|, else: ~S|does not exist|}"
      end)
      result
    end

    # Private functions
    defp do_add_job(scheduler_module, job) do
      table = get_ets_by_scheduler(scheduler_module)
      :ets.insert(table, entry = {job_key(job.name), job})
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] inserting [#{inspect entry}] into Persistent ETS table [#{table}]"
      end)
      :ok
    end

    defp do_get_jobs(scheduler_module) do
      table = get_ets_by_scheduler(scheduler_module)
      result =
        case :ets.match(table, {{:job, :'_'}, :'$1'}) do
          [] -> :not_applicable
          [_h|_t] = jobs -> jobs |> List.flatten
        end
      Logger.debug(fn ->
        "[#{inspect(Node.self())}][#{__MODULE__}] jobs are: #{inspect result}"
      end)
      result
    end

    defp do_delete_job(scheduler_module, job_name) do
      table = get_ets_by_scheduler(scheduler_module)
      :ets.delete(table, job_key(job_name))
      :ok
    end

    defp do_update_job_state(scheduler_module, job_name, state) do
      table = get_ets_by_scheduler(scheduler_module)
      job =
        case :ets.lookup(table, {:job, job_name}) do
          [] -> raise "Job #{job_name} does not exist in the storage" # TODO: should we raise here or should we handle the situation with a return value of a special kind?
          [j|_t] -> j
        end
      upd_job = %{job|state: state}
      :ets.update_element(table, job_key(job_name), {1, upd_job})
      :ok
    end

    defp do_get_last_execution_date(scheduler_module) do
      table = get_ets_by_scheduler(scheduler_module)
      case :ets.lookup(table, :last_execution_date) do
        [] -> :unknown
        [{:last_execution_date, date}|_t] -> date
        {:last_execution_date, d} -> d
      end
    end

    defp do_update_last_execution_date(scheduler_module,  last_execution_date) do
      table = get_ets_by_scheduler(scheduler_module)
      :ets.insert(table, {:last_execution_date, last_execution_date})
      :ok
    end

    defp do_purge(scheduler_module) do
      table = get_ets_by_scheduler(scheduler_module)
      :ets.delete_all_objects(table)
      :ok
    end

    @behaviour Quantum.Storage.Adapter

    def jobs(scheduler_module) do
      __server__ |> GenServer.call({:jobs, scheduler_module})
    end
    def add_job(scheduler_module, job) do
      __server__ |> GenServer.call({:add_job, scheduler_module, job})
    end
    def delete_job(scheduler_module, job_name) do
      __server__ |> GenServer.call({:delete_job, scheduler_module, job_name})
    end
    def update_job_state(scheduler_module, job_name, state) do
      __server__ |> GenServer.call({:update_job_state, scheduler_module, job_name, state})
    end
    def last_execution_date(scheduler_module) do
      __server__ |> GenServer.call({:last_execution_date, scheduler_module})
    end
    def update_last_execution_date(scheduler_module, last_execution_date) do
      __server__ |> GenServer.call({:update_last_execution_date, scheduler_module, last_execution_date})
    end
    def purge(scheduler_module) do
      __server__ |> GenServer.call({:purge, scheduler_module})
    end
  end
end
