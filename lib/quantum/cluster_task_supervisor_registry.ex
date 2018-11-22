defmodule Quantum.ClusterTaskSupervisorRegistry do
  @moduledoc false
  # Provide means to find all nodes running the task registry

  use GenServer

  alias __MODULE__.{InitOpts, StartOpts, State}

  @doc false
  @spec start_link(StartOpts.t()) :: GenServer.on_start()
  def start_link(%StartOpts{name: name} = opts) do
    GenServer.start_link(
      __MODULE__,
      struct!(
        InitOpts,
        opts
        |> Map.take([:task_supervisor_reference, :group_name, :global])
        |> Map.put_new(:group_name, Module.concat(name, Group))
      ),
      name: name
    )
  end

  @doc false
  @impl true
  def init(%InitOpts{
        task_supervisor_reference: task_supervisor,
        group_name: group_name,
        global: true
      }) do
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
     %State{
       group_name: group_name,
       task_supervisor_pid: task_supervisor_pid,
       monitor_ref: monitor_ref,
       global: true
     }}
  end

  def init(%InitOpts{
        task_supervisor_reference: task_supervisor,
        group_name: group_name,
        global: false
      }) do
    task_supervisor_pid = GenServer.whereis(task_supervisor)

    monitor_ref = Process.monitor(task_supervisor_pid)

    {:ok,
     %State{
       group_name: group_name,
       task_supervisor_pid: task_supervisor_pid,
       monitor_ref: monitor_ref,
       global: false
     }}
  end

  @doc false
  @impl true
  def handle_call(:pids, _from, %State{group_name: group_name, global: true} = state) do
    {:reply, Swarm.members(group_name), state}
  end

  def handle_call(
        :pids,
        _from,
        %State{task_supervisor_pid: task_supervisor_pid, global: false} = state
      ) do
    {:reply, [task_supervisor_pid], state}
  end

  @doc false
  @impl true
  def handle_info(
        {:DOWN, monitor_ref, :process, task_supervisor_pid, _reason},
        %State{
          group_name: group_name,
          task_supervisor_pid: task_supervisor_pid,
          monitor_ref: monitor_ref,
          global: true
        } = state
      ) do
    Swarm.leave(group_name, task_supervisor_pid)
    {:stop, :terminate, state}
  end

  def handle_info(
        {:DOWN, monitor_ref, :process, task_supervisor_pid, _reason},
        %State{
          task_supervisor_pid: task_supervisor_pid,
          monitor_ref: monitor_ref,
          global: false
        } = state
      ) do
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
