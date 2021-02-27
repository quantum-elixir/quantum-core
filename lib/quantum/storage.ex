defmodule Quantum.Storage do
  @moduledoc """
  Behaviour to be implemented by all Storage Adapters.

  The calls to the storage are blocking, make sure they're fast to not block the job execution.
  """

  alias Quantum.Job

  @typedoc """
  The location of the `server`.

  ### Values

  * `nil` if the storage was not started
  * `server()` if the storage was started

  """
  @type storage_pid :: nil | GenServer.server()

  @doc """
  Storage child spec

  If the storage does not need a process, specify a function that returns `:ignore`.

  ### Values

  * `:scheduler` - The Scheduler

  """
  @callback child_spec(init_arg :: Keyword.t()) :: Supervisor.child_spec()

  @doc """
  Load saved jobs from storage.

  Returns `:not_applicable` if the storage has never received an `add_job` call or after it has been purged.
  In this case the jobs from the configuration will be loaded.
  """
  @callback jobs(storage_pid :: storage_pid) ::
              :not_applicable | [Job.t()]

  @doc """
  Save new job in storage.
  """
  @callback add_job(storage_pid :: storage_pid, job :: Job.t()) ::
              :ok

  @doc """
  Delete new job in storage.
  """
  @callback delete_job(storage_pid :: storage_pid, job :: Job.name()) :: :ok

  @doc """
  Change Job State from given job.
  """
  @callback update_job_state(storage_pid :: storage_pid, job :: Job.name(), state :: Job.state()) ::
              :ok

  @doc """
  Load last execution time from storage.

  Returns `:unknown` if the storage does not know the last execution time.
  In this case all jobs will be run at the next applicable date.
  """
  @callback last_execution_date(storage_pid :: storage_pid) :: :unknown | NaiveDateTime.t()

  @doc """
  Update last execution time to given date.
  """
  @callback update_last_execution_date(
              storage_pid :: storage_pid,
              last_execution_date :: NaiveDateTime.t()
            ) :: :ok

  @doc """
  Purge all date from storage and go back to initial state.
  """
  @callback purge(storage_pid :: storage_pid) :: :ok

  @doc """
  Updates existing job in storage.

  This callback is optional. If not implemented then the `c:delete_job/2`
  and then the `c:add_job/2` callbacks will be called instead.
  """
  @callback update_job(storage_pid :: storage_pid, job :: Job.t()) :: :ok

  @optional_callbacks update_job: 2
end
