defmodule Quantum.Application do
  @moduledoc false

  use Application

  @deps Application.get_env(:quantum, :date_library, Quantum.DateLibrary.Timex)

  if @deps do
    def start(_type, _args) do
      Application.ensure_all_started(@deps, :permanent)
      {:ok, self()}
    end
  else
    def start(_type, _args) do
      {:ok, self()}
    end
  end
end
