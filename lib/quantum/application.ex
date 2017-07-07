defmodule Quantum.Application do
  @moduledoc false

  use Application

  @dependency_application Application.get_env(:quantum, :date_library, Quantum.DateLibrary.Timex)
    .dependency_application()

  def start(_type, _args) do
    start_dependencies(@dependency_application)

    {:ok, self()}
  end

  defp start_dependencies(nil),
    do: nil
  defp start_dependencies(application) when is_atom(application),
    do: Application.ensure_all_started(application, :permanent)
end
