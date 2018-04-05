defmodule Quantum.Storage.Noop do
  @moduledoc """
  Empty implementation of a `Quantum.Storage.Adapter`.
  """

  @behaviour Quantum.Storage.Adapter

  def jobs(_scheduler_module), do: :not_applicable
  def add_job(_scheduler_module, _job), do: :ok
  def delete_job(_scheduler_module, _job_name), do: :ok
  def update_job_state(_scheduler_module, _job_name, _state), do: :ok
  def last_execution_date(_scheduler_module), do: :unknown
  def update_last_execution_date(_scheduler_module, _last_execution_date), do: :ok
  def purge(_scheduler_module), do: :ok
end
