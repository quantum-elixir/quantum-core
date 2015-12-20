defmodule Quantum.Application do

  @moduledoc false

  import Quantum.Normalizer

  use Application

  def start(_type, _args) do
    jobs = :quantum |> Application.get_env(:cron, []) |> Enum.map(&normalize/1)
    state = %{jobs: jobs, d: nil, h: nil, m: nil, w: nil, r: nil}
    Quantum.Supervisor.start_link(state)
  end

end
