defmodule Quantum.Application do
  use Application

  @moduledoc false

  def start(_type, _args) do
    GenServer.start_link(Quantum, %{}, [name: Quantum])
  end

end
