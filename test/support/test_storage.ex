defmodule Quantum.Storage.Test do
  @moduledoc """
  Test implementation of a `Quantum.Storage`.
  """

  @behaviour Quantum.Storage

  use GenServer

  def start_link(_opts), do: send_and_wait(:jobs, :start_link, :ignore)

  @doc false
  @impl GenServer
  def init(_args), do: {:ok, nil}

  @impl Quantum.Storage
  def jobs(_storage_pid), do: send_and_wait(:jobs, nil, :not_applicable)

  @impl Quantum.Storage
  def add_job(_storage_pid, job), do: send_and_wait(:add_job, job)

  @impl Quantum.Storage
  def delete_job(_storage_pid, job_name), do: send_and_wait(:delete_job, job_name)

  @impl Quantum.Storage
  def update_job_state(_storage_pid, job_name, state),
    do: send_and_wait(:update_job_state, {job_name, state})

  @impl Quantum.Storage
  def last_execution_date(_storage_pid), do: send_and_wait(:last_execution_date, nil, :unknown)

  @impl Quantum.Storage
  def update_last_execution_date(_storage_pid, last_execution_date),
    do: send_and_wait(:update_last_execution_date, last_execution_date)

  @impl Quantum.Storage
  def purge(_storage_pid), do: send_and_wait(:purge, nil)

  # Used for Small Test Storages
  defmacro __using__(_) do
    quote do
      @behaviour Quantum.Storage

      import Quantum.Storage.Test

      use GenServer

      def start_link(_opts), do: send_and_wait(:jobs, :start_link, :ignore)

      @doc false
      @impl GenServer
      def init(_args), do: {:ok, nil}

      @impl Quantum.Storage
      def jobs(_storage_pid), do: send_and_wait(:jobs, nil, :not_applicable)

      @impl Quantum.Storage
      def add_job(_storage_pid, job), do: send_and_wait(:add_job, job)

      @impl Quantum.Storage
      def delete_job(_storage_pid, job_name), do: send_and_wait(:delete_job, job_name)

      @impl Quantum.Storage
      def update_job_state(_storage_pid, job_name, state),
        do: send_and_wait(:update_job_state, job_name, state)

      @impl Quantum.Storage
      def last_execution_date(_storage_pid),
        do: send_and_wait(:last_execution_date, nil, :unknown)

      @impl Quantum.Storage
      def update_last_execution_date(_storage_pid, last_execution_date),
        do: send_and_wait(:update_last_execution_date, last_execution_date)

      @impl Quantum.Storage
      def purge(_storage_pid), do: send_and_wait(:purge, nil)

      defoverridable Quantum.Storage
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

defmodule Quantum.Storage.TestWithUpdate do
  @moduledoc """
  Test implementation of a `Quantum.Storage` that overrides `c:update_job/2`.
  """
  use Quantum.Storage.Test

  @impl Quantum.Storage
  def update_job(_storage_pid, job), do: send_and_wait(:update_job, job)
end
