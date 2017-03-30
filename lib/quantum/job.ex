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

  def executable?(job) do
    cond do
      job.state != :active    -> false # Do not execute inactive jobs
      not node() in job.nodes -> false # Job shall not run on this node
      job.overlap == true     -> true  # Job may overlap
      job.pid == nil          -> true  # Job has not been started
      !is_alive?(job.pid)     -> false # Previous job is still running
      true                    -> true  # Previous job has finished
    end
  end

  defp is_alive?(pid) do
    case :rpc.pinfo(pid) do
      :undefined -> false
      _ -> true
    end
  end

end
