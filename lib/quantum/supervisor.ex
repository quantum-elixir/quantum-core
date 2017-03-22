defmodule Quantum.Supervisor do
  @moduledoc false
  use Supervisor

  require Logger
  alias Quantum.Normalizer

  @defaults [global?: false, cron: [], timezone: :utc, timeout: 5_000]

  @doc """
  Starts the quantum supervisor.
  """
  def start_link(quantum, otp_app, opts) do
    name = Keyword.get(opts, :name, quantum)
    Supervisor.start_link(__MODULE__, {quantum, otp_app, opts}, [name: name])
  end

  @doc """
  Retrieves the runtime configuration.
  """
  def runtime_config(type, quantum, otp_app, custom) do
    if config = Application.get_env(otp_app, quantum) do
      config = [otp_app: otp_app, quantum: quantum] ++
               (@defaults |> Keyword.merge(config) |> Keyword.merge(custom))

      jobs = config
      |> Keyword.get(:cron)
      |> Enum.map(&Normalizer.normalize/1)
      |> remove_jobs_with_duplicate_names(quantum)

      scheduler = if Keyword.fetch!(config, :global?),
        do: {:global, Module.concat(quantum, Scheduler)},
        else: Module.concat(quantum, Scheduler)

      task_supervisor = Module.concat(quantum, Task.Supervisor)

      config = config
      |> Keyword.put(:cron, jobs)
      |> Keyword.put(:scheduler, scheduler)
      |> Keyword.put(:task_supervisor, task_supervisor)

      case quantum_init(type, quantum, config) do
        {:ok, config} ->
          {:ok, config}
        :ignore ->
          :ignore
      end
    else
      raise ArgumentError,
        "configuration for #{inspect quantum} not specified in #{inspect otp_app} environment"
    end
  end

  defp quantum_init(type, quantum, config) do
    if Code.ensure_loaded?(quantum) and function_exported?(quantum, :init, 2) do
      quantum.init(type, config)
    else
      {:ok, config}
    end
  end

  defp remove_jobs_with_duplicate_names(job_list, quantum) do
    Enum.reduce(job_list, [], fn({name, job}, acc) ->
      if name && Enum.member?(Keyword.keys(acc), name) do
        Logger.warn("Job with name '#{name}' of quantum '#{quantum}' not started due to duplicate job name")
        acc
      else
        [{name, job} | acc]
      end
    end)
  end

  ## Callbacks

  def init({quantum, otp_app, opts}) do
    case runtime_config(:supervisor, quantum, otp_app, opts) do
      {:ok, opts} ->
        children = [
          supervisor(Task.Supervisor, [[name: Keyword.get(opts, :task_supervisor)]]),
          worker(Quantum.Scheduler, [opts], restart: :permanent)
        ]
        supervise(children, strategy: :one_for_one)
      :ignore ->
        :ignore
    end
  end
end
