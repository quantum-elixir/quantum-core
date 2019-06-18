defmodule Quantum do
  @moduledoc """
  Contains config functions to aid the rest of the lib
  """

  require Logger

  alias Quantum.{Job, Normalizer, RunStrategy.Random, Storage.Noop}

  @defaults [
    global: false,
    cron: [],
    timeout: 5_000,
    schedule: nil,
    overlap: true,
    state: :active,
    timezone: :utc,
    run_strategy: {Random, :cluster},
    debug_logging: true
  ]

  @doc """
  Retrieves only scheduler related configuration.
  """
  def scheduler_config(quantum, otp_app, custom) do
    config =
      @defaults
      |> Keyword.merge(Application.get_env(otp_app, quantum, []))
      |> Keyword.merge(custom)
      |> Keyword.merge(otp_app: otp_app, quantum: quantum)

    config
    |> Keyword.put_new(:quantum, quantum)
    |> Keyword.put_new(:scheduler, quantum)
    |> update_in([:schedule], &Normalizer.normalize_schedule/1)
    |> Keyword.put_new(:storage, Noop)
  end

  @doc """
  Retrieves the comprehensive runtime configuration.
  """
  def runtime_config(quantum, otp_app, custom) do
    config = scheduler_config(quantum, otp_app, custom)

    # Load Jobs from Config
    jobs =
      config
      |> Keyword.get(:jobs, [])
      |> Enum.map(&Normalizer.normalize(quantum.new_job(config), &1))
      |> remove_jobs_with_duplicate_names(quantum)

    Keyword.put(config, :jobs, jobs)
  end

  defp remove_jobs_with_duplicate_names(job_list, quantum) do
    job_list
    |> Enum.reduce(%{}, fn %Job{name: name} = job, acc ->
      if Enum.member?(Map.keys(acc), name) do
        Logger.warn(
          "Job with name '#{name}' of quantum '#{quantum}' not started due to duplicate job name"
        )

        acc
      else
        Map.put_new(acc, name, job)
      end
    end)
    |> Map.values()
  end
end
