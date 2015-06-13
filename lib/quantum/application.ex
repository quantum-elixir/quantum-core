defmodule Quantum.Application do

  @moduledoc false

  use Application

  def start(_type, _args) do
    GenServer.start_link(Quantum, %{}, [name: Quantum])
  end

end
