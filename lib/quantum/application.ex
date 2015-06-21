defmodule Quantum.Application do

  @moduledoc false

  use Application

  def start(_type, _args) do
    jobs = Application.get_env(:quantum, :cron, []) |> Enum.map(&Quantum.Normalizer.normalize/1)
    GenServer.start_link(Quantum, %{jobs: jobs, d: nil, h: nil, m: nil, w: nil}, [name: Quantum])
  end

end
