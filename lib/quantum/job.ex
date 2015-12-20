defmodule Quantum.Job do

  @moduledoc false

  defstruct [
    name: nil,
    schedule: nil,
    task: nil, # {module, function}
    args: [],
    state: :active, # active/inactive
    nodes: [node()],
    overlap: true,
    pid: nil
  ]

  @type t :: %Quantum.Job{}

end
