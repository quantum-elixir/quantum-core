defmodule Quantum.Storage.Noop do
  @moduledoc """
  Empty implementation of a `Quantum.Storage.Adapter`.
  """

  @behaviour Quantum.Storage.Adapter

  @impl Quantum.Storage.Adapter
  def jobs(_scheduler_module), do: :not_applicable

  @impl Quantum.Storage.Adapter
  def add_job(_scheduler_module, _job), do: :ok

  @impl Quantum.Storage.Adapter
  def delete_job(_scheduler_module, _job_name), do: :ok

  @impl Quantum.Storage.Adapter
  def update_job_state(_scheduler_module, _job_name, _state), do: :ok

  @impl Quantum.Storage.Adapter
  def last_execution_date(_scheduler_module), do: :unknown

  @impl Quantum.Storage.Adapter
  def update_last_execution_date(_scheduler_module, _last_execution_date), do: :ok

  @impl Quantum.Storage.Adapter
  def purge(_scheduler_module), do: :ok
end
