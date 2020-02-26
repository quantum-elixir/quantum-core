defmodule Quantum.Storage.Test do
  @moduledoc """
  Test implementation of a `Quantum.Storage.Adapter`.
  """

  @behaviour Quantum.Storage.Adapter

  def jobs(scheduler_module), do: send_and_wait(:jobs, scheduler_module, :not_applicable)
  def add_job(scheduler_module, job), do: send_and_wait(:add_job, {scheduler_module, job})

  def delete_job(scheduler_module, job_name),
    do: send_and_wait(:delete_job, {scheduler_module, job_name})

  def update_job_state(scheduler_module, job_name, state),
    do: send_and_wait(:update_job_state, {scheduler_module, job_name, state})

  def last_execution_date(scheduler_module),
    do: send_and_wait(:last_execution_date, scheduler_module, :unknown)

  def update_last_execution_date(scheduler_module, last_execution_date),
    do: send_and_wait(:update_last_execution_date, {scheduler_module, last_execution_date})

  def purge(scheduler_module), do: send_and_wait(:purge, scheduler_module)

  @doc false
  # Used for Small Test Storages
  defmacro __using__(_) do
    quote do
      @behaviour Quantum.Storage.Adapter

      alias Quantum.Storage.Test

      def jobs(scheduler_module), do: Test.send_and_wait(:jobs, scheduler_module, :not_applicable)

      def add_job(scheduler_module, job),
        do: Test.send_and_wait(:add_job, {scheduler_module, job})

      def delete_job(scheduler_module, job_name),
        do: Test.send_and_wait(:delete_job, {scheduler_module, job_name})

      def update_job_state(scheduler_module, job_name, state),
        do: Test.send_and_wait(:update_job_state, {scheduler_module, job_name, state})

      def last_execution_date(scheduler_module),
        do: Test.send_and_wait(:last_execution_date, scheduler_module, :unknown)

      def update_last_execution_date(scheduler_module, last_execution_date),
        do:
          Test.send_and_wait(:update_last_execution_date, {scheduler_module, last_execution_date})

      def purge(scheduler_module), do: Test.send_and_wait(:purge, scheduler_module)

      defoverridable Quantum.Storage.Adapter
    end
  end

  def send_and_wait(fun, args, default \\ :ok) do
    test_pid = find_test_pid(self())

    if !is_nil(test_pid) do
      ref = make_ref()

      send(test_pid, {fun, args, {self(), ref}})
    end

    default
  end

  defp find_test_pid(pid) do
    pid
    |> Process.info()
    |> case do
      nil -> []
      other -> other
    end
    |> Keyword.get(:dictionary, [])
    |> Map.new()
    |> case do
      %{test_pid: pid} ->
        pid

      %{"$ancestors": ancestors} ->
        Enum.find_value(ancestors, fn ancestor_pid ->
          find_test_pid(ancestor_pid)
        end)

      _ ->
        nil
    end
  end
end
