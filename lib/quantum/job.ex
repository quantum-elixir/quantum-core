defmodule Quantum.Job do

  @moduledoc false

  @default_schedule Application.get_env(:quantum, :default_schedule, nil)
  @default_args     Application.get_env(:quantum, :default_args, [])
  @default_overlap  Application.get_env(:quantum, :default_overlap, true)
  @default_timezone Application.get_env(:quantum, :timezone, :utc)

  defstruct [
    name: nil,
    schedule: @default_schedule,
    task: nil, # {module, function}
    args: @default_args,
    state: :active, # active/inactive
    nodes: nil,
    overlap: @default_overlap,
    pid: nil,
    timezone: @default_timezone
  ]

  @type t :: %Quantum.Job{}

end
