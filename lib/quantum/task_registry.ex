defmodule Quantum.TaskRegistry do
  @moduledoc false

  # Registry to check if a task is already running on a node.

  alias __MODULE__.StartOpts
  alias Quantum.Job

  # Start the registry
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name, listeners: listeners}) do
    [keys: :unique, name: name, listeners: listeners]
    |> Registry.start_link()
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.monitor(pid)
        {:ok, pid}

      {:error, _reason} = error ->
        error
    end
  end

  @spec child_spec(options :: StartOpts.t()) :: Supervisor.child_spec()
  def child_spec(options),
    do:
      []
      |> Registry.child_spec()
      |> Map.put(:start, {__MODULE__, :start_link, [options]})

  # Mark a task as Running
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, running_job.name, Node.self())
  #     :already_running
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, Node.self())
  #     :marked_running
  @spec mark_running(server :: atom, task :: Job.name(), node :: Node.t()) ::
          :already_running | :marked_running
  def mark_running(server, task, node) do
    server
    |> Registry.register({task, node}, true)
    |> case do
      {:ok, _pid} -> :marked_running
      {:error, {:already_registered, _other_pid}} -> :already_running
    end
  end

  # Mark a task as Finished
  #
  # ### Examples
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, running_job.name, Node.self())
  #     :ok
  #
  #     iex> Quantum.TaskRegistry.mark_running(server, not_running_job.name, Node.self())
  #     :ok
  @spec mark_finished(server :: atom, task :: Job.name(), node :: Node.t()) :: :ok
  def mark_finished(server, task, node) do
    Registry.unregister(server, {task, node})
  end
end
