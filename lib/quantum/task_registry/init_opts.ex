defmodule Quantum.TaskRegistry.InitOpts do
  @moduledoc false

  # Init Options for Quantum.TaskRegistry

  @type t :: %__MODULE__{}

  @enforce_keys []
  defstruct @enforce_keys
end
