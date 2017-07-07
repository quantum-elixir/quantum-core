defmodule Quantum.Application do
  @moduledoc false

  use Application

  @dependency_application Application.get_env(:quantum, :date_library, Quantum.DateLibrary.Timex)
    .dependency_application()

  case @dependency_application do
    nil ->
      def start(_type, _args) do
        {:ok, self()}
      end
    _ ->
      def start(_type, _args) do
        Application.ensure_all_started(@dependency_application, :permanent)
        {:ok, self()}
      end
  end
end
