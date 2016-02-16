defmodule Quantum.Application do

  @moduledoc false

  import Quantum.Normalizer
  require Logger

  use Application

  def start(_type, _args) do
    jobs = :quantum |> Application.get_env(:cron, [])
    |> Enum.map(&normalize/1)
    |> remove_jobs_with_duplicate_names
    state = %{jobs: jobs, d: nil, h: nil, m: nil, w: nil, r: nil}
    Quantum.Supervisor.start_link(state)
  end

  def remove_jobs_with_duplicate_names(job_list) do
    Enum.reduce(job_list, [], fn({name, job}, acc) ->
      if name && Enum.member?(Keyword.keys(acc), name) do
        Logger.warn("A Quantum-job with the name \"#{name}\" has not been started because this job-name already exists.")
        acc
      else
        [{name, job} | acc]
      end
    end)
  end

end
