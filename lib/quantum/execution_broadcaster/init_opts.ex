defmodule Quantum.ExecutionBroadcaster.InitOpts do
  @moduledoc false

  # Init Options

  alias Quantum.Scheduler
  alias Quantum.Storage.Adapter, as: StorageAdapter

  @type t :: %__MODULE__{
          job_broadcaster: GenServer.server(),
          clock_broadcaster: GenServer.server(),
          storage: StorageAdapter,
          scheduler: Scheduler,
          debug_logging: boolean()
        }

  @enforce_keys [:job_broadcaster, :clock_broadcaster, :storage, :scheduler, :debug_logging]

  defstruct @enforce_keys

  def fields, do: @enforce_keys
end
