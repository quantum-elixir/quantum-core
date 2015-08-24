defmodule Quantum.Job do

  defstruct [
    name: nil,
    schedule: nil,
    task: nil, # {module, function}
    args: [],
    state: :active # active/suspended
  ]

  @type t :: %Quantum.Job{}

end
