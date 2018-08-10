defmodule Quantum.ClusterTaskSupervisorRegistry do
  @moduledoc false
  # Provide means to find all nodes running the task registry

  use GenServer

  @doc false
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      {
        Keyword.fetch!(opts, :task_supervisor),
        Keyword.get(opts, :group_name, Module.concat(name, Group))
      },
      name: name
    )
  end

  @doc false
  @impl true
  def init({task_supervisor, group_name}) do
    task_supervisor_pid = GenServer.whereis(task_supervisor)

    monitor_ref = Process.monitor(task_supervisor_pid)

    # TODO: Find better way without poluting the atom table
    :yes =
      Swarm.register_name(
        Module.concat(group_name, :"#{inspect(make_ref())}"),
        task_supervisor_pid
      )

    :ok = Swarm.join(group_name, task_supervisor_pid)

    {:ok,
     %{group_name: group_name, task_supervisor_pid: task_supervisor_pid, monitor_ref: monitor_ref}}
  end

  @doc false
  @impl true
  def handle_call(:pids, _from, %{group_name: group_name} = state) do
    {:reply, Swarm.members(group_name), state}
  end

  @doc false
  @impl true
  def handle_info(
        {:DOWN, monitor_ref, :process, task_supervisor_pid, _reason},
        %{
          group_name: group_name,
          task_supervisor_pid: task_supervisor_pid,
          monitor_ref: monitor_ref
        } = state
      ) do
    Swarm.leave(group_name, task_supervisor_pid)
    {:stop, :terminate, state}
  end

  @doc false
  # Retrieve pids running the linked gen server
  def pids(server \\ __MODULE__) do
    GenServer.call(server, :pids)
  end

  @doc false
  # Retrieve pids running the linked gen server
  def nodes(server \\ __MODULE__) do
    server
    |> pids
    |> Enum.map(&node/1)
    |> Enum.uniq()
  end
end
