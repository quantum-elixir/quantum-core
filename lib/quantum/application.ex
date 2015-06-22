defmodule Quantum.Application do

  @moduledoc false

  use Application

  def start(_type, _args) do
    jobs = Application.get_env(:quantum, :cron, []) |> Enum.map(&Quantum.Normalizer.normalize/1)
    state = %{jobs: jobs, d: nil, h: nil, m: nil, w: nil, r: nil}
    GenServer.start_link(Quantum, state, [name: Quantum])
  end

end
