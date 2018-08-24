defmodule Quantum.HandoffHelper do
  @moduledoc false

  def initiate_handoff(from, to) do
    {:resume, handoff_state} = GenServer.call(from, {:swarm, :begin_handoff})
    GenServer.cast(to, {:swarm, :end_handoff, handoff_state})
    Process.send(GenServer.whereis(from), {:swarm, :die}, [])
  end

  def resolve_conflict(from, to) do
    {:resume, handoff_state} = GenServer.call(from, {:swarm, :begin_handoff})
    GenServer.cast(to, {:swarm, :resolve_conflict, handoff_state})
    Process.send(GenServer.whereis(from), {:swarm, :die}, [])
  end
end
