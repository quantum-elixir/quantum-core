defmodule Quantum.Storage.Noop do
  @moduledoc """
  Empty implementation of a `Quantum.Storage`.
  """

  @behaviour Quantum.Storage

  @impl Quantum.Storage
  def jobs(_scheduler_module), do: :not_applicable

  @impl Quantum.Storage
  def add_job(_scheduler_module, _job), do: :ok

  @impl Quantum.Storage
  def delete_job(_scheduler_module, _job_name), do: :ok

  @impl Quantum.Storage
  def update_job_state(_scheduler_module, _job_name, _state), do: :ok

  @impl Quantum.Storage
  def last_execution_date(_scheduler_module), do: :unknown

  @impl Quantum.Storage
  def update_last_execution_date(_scheduler_module, _last_execution_date), do: :ok

  @impl Quantum.Storage
  def purge(_scheduler_module), do: :ok
end
