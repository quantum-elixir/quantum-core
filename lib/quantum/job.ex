defmodule Quantum.Job do

  @moduledoc false

  @default_schedule Application.get_env(:quantum, :default_schedule, nil)
  @default_args     Application.get_env(:quantum, :default_args, [])
  @default_nodes    Application.get_env(:quantum, :default_nodes, [node()])
  @default_overlap  Application.get_env(:quantum, :default_overlap, true)

  defstruct [
    name: nil,
    schedule: @default_schedule,
    task: nil, # {module, function}
    args: @default_args,
    state: :active, # active/inactive
    nodes: @default_nodes,
    overlap: @default_overlap,
    pid: nil
  ]

  @type t :: %Quantum.Job{}

end
