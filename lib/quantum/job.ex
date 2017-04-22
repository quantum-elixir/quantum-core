defmodule Quantum.Job do
  @moduledoc """
  This Struct defines a Job.

  ## Usage

  The struct should never be defined by hand. Use `Acme.Scheduler.new_job/0` to create a new job and use the setters mentioned
  below to mutate the job.

  This is to ensure type safety.

  """

  alias Crontab.CronExpression

  defstruct [
    name: nil,
    schedule: nil,
    task: nil,
    state: :active,
    nodes: [],
    overlap: nil,
    pid: nil,
    timezone: nil
  ]

  @type state :: :active | :inactive
  @type task :: {atom, atom, [any]} | (() -> any)
  @type timezone :: :utc | :local | String.t
  @type schedule :: Crontab.CronExpression.t
  @type nodes :: [Node.t]

  @opaque t :: %__MODULE__{
    name: String.t,
    schedule: schedule,
    task: task,
    state: state,
    nodes: nodes,
    overlap: boolean,
    pid: pid | nil,
    timezone: timezone
  }

  @doc """
  Determines if a Job is executable.

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_state(:inactive)
      ...> |> Quantum.Job.executable?
      false

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.executable?
      true

  """
  @spec executable?(t) :: boolean
  def executable?(job) do
    cond do
      job.state != :active    -> false # Do not execute inactive jobs
      not node() in job.nodes -> false # Job shall not run on this node
      job.overlap == true     -> true  # Job may overlap
      job.pid == nil          -> true  # Job has not been started
      is_alive?(job.pid)      -> false # Previous job is still running
      true                    -> true  # Previous job has finished
    end
  end

  defp is_alive?(pid) do
    case :rpc.pinfo(pid) do
      :undefined -> false
      _ -> true
    end
  end

  @doc """
  Sets a jobs name.

  ### Parameters

    1. `job` - The job struct to modify
    2. `name` - The name to set

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_name(:name)
      ...> |> Map.get(:name)
      :name

  """
  @spec set_name(t, atom) :: t
  def set_name(job = %__MODULE__{}, name) when is_atom(name), do: Map.put(job, :name, name)

  @doc """
  Sets a jobs schedule.

  ### Parameters

    1. `job` - The job struct to modify
    2. `schedule` - The schedule to set. May only be of type `%Crontab.CronExpression{}`

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("*/7"))
      ...> |> Map.get(:schedule)
      Crontab.CronExpression.Parser.parse!("*/7")

  """
  @spec set_schedule(t, CronExpression.t) :: t
  def set_schedule(job = %__MODULE__{}, schedule = %CronExpression{}), do: Map.put(job, :schedule, schedule)

  @doc """
  Sets a jobs schedule.

  ### Parameters

    1. `job` - The job struct to modify
    2. `schedule` - The schedule to set. May only be of type `%Crontab.CronExpression{}`

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("*/7"))
      ...> |> Map.get(:schedule)
      Crontab.CronExpression.Parser.parse!("*/7")

  """
  @spec set_task(t, task) :: t
  def set_task(job = %__MODULE__{}, task = {module, function, args})
  when is_atom(module) and is_atom(function) and is_list(args), do: Map.put(job, :task, task)
  def set_task(job = %__MODULE__{}, task) when is_function(task, 0), do: Map.put(job, :task, task)

  @doc """
  Sets a jobs state.

  ### Parameters

    1. `job` - The job struct to modify
    2. `state` - The state to set

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_state(:active)
      ...> |> Map.get(:state)
      :active

  """
  @spec set_state(t, state) :: t
  def set_state(job = %__MODULE__{}, :active), do: Map.put(job, :state, :active)
  def set_state(job = %__MODULE__{}, :inactive), do: Map.put(job, :state, :inactive)

  @doc """
  Sets a jobs nodes to run on.

  ### Parameters

    1. `job` - The job struct to modify
    2. `nodes` - The nodes to set

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_nodes([:one, :two])
      ...> |> Map.get(:nodes)
      [:one, :two]

  """
  @spec set_nodes(t, [node]) :: t
  def set_nodes(job = %__MODULE__{}, nodes), do: Map.put(job, :nodes, nodes)

  @doc """
  Sets a jobs overlap.

  ### Parameters

    1. `job` - The job struct to modify
    2. `overlap` - Enable / Disable Overlap

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_overlap(false)
      ...> |> Map.get(:overlap)
      false

  """
  @spec set_overlap(t, boolean) :: t
  def set_overlap(job = %__MODULE__{}, overlap?) when is_boolean(overlap?), do: Map.put(job, :overlap, overlap?)

  @doc """
  Sets a jobs timezone.

  ### Parameters

    1. `job` - The job struct to modify
    2. `timezone` - The timezone to set.

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_timezone("Europe/Zurich")
      ...> |> Map.get(:timezone)
      "Europe/Zurich"

  """
  @spec set_timezone(t, String.t | :utc | :local) :: t
  def set_timezone(job = %__MODULE__{}, timezone), do: Map.put(job, :timezone, timezone)
end
