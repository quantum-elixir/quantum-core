defmodule Quantum.Storage.Noop do
  @moduledoc """
  Empty implementation of a `Quantum.Storage`.
  """

  @behaviour Quantum.Storage

  use GenServer

  @doc false
  @impl GenServer
  def init(_args), do: {:ok, nil}

  @doc false
  def start_link(_opts), do: :ignore

  @doc false
  @impl Quantum.Storage
  def jobs(_storage_pid), do: :not_applicable

  @doc false
  @impl Quantum.Storage
  def add_job(_storage_pid, _job), do: :ok

  @doc false
  @impl Quantum.Storage
  def delete_job(_storage_pid, _job_name), do: :ok

  @doc false
  @impl Quantum.Storage
  def update_job_state(_storage_pid, _job_name, _state), do: :ok

  @doc false
  @impl Quantum.Storage
  def last_execution_date(_storage_pid), do: :unknown

  @doc false
  @impl Quantum.Storage
  def update_last_execution_date(_storage_pid, _last_execution_date), do: :ok

  @doc false
  @impl Quantum.Storage
  def purge(_storage_pid), do: :ok
end
