defmodule Quantum.Storage.Adapter do
  @moduledoc """
  Bahaviour to be implemented by all Storage Adapters.
  """

  alias Quantum.Job

  @typedoc """
  The calling scheduler Module
  """
  @type scheduler_module :: atom

  @typedoc """
  The expected return is `:ok`, every other result will terminate the scheduler.
  """
  @type ok :: :ok

  @doc """
  Load saved jobs from storage

  Returns `:not_applicable` if the storage has never received an `add_job` call or after it has been purged.
  In this case the jobs from the configuration weill be loaded.
  """
  @callback jobs(scheduler_module) :: :not_applicable | [Job.t()]

  @doc """
  Save new job in storage.
  """
  @callback add_job(scheduler_module, job :: Job.t()) :: ok

  @doc """
  Delete new job in storage.
  """
  @callback delete_job(scheduler_module, job :: Job.name()) :: ok

  @doc """
  Change Job State from given job.
  """
  @callback update_job_state(scheduler_module, job :: Job.name(), state :: Job.state()) :: ok

  @doc """
  Load last execution time from storage

  Returns `:unknown` if the storage does not know the last execution time.
  In this case all jobs will be run at the next applicable date.
  """
  @callback last_execution_date(scheduler_module) :: :unknown | NaiveDateTime.t()

  @doc """
  Update last execution time to given date.
  """
  @callback update_last_execution_date(
              scheduler_module,
              last_execution_date :: NaiveDateTime.t()
            ) :: ok

  @doc """
  Purge all date from storage and go back to initial state.
  """
  @callback purge(scheduler_module) :: ok
end
