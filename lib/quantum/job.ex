defmodule Quantum.Job do
  @moduledoc """
  This Struct defines a Job.

  ## Usage

  The struct should never be defined by hand. Use `Acme.Scheduler.new_job/0` to create a new job and use the setters mentioned
  below to mutate the job.

  This is to ensure type safety.

  """

  alias Crontab.CronExpression

  @enforce_keys [:run_strategy, :overlap, :timezone]

  defstruct [
    :run_strategy,
    :overlap,
    :timezone,
    name: nil,
    schedule: nil,
    task: nil,
    state: :active,
    pids: [],
  ]

  @type state :: :active | :inactive
  @type task :: {atom, atom, [any]} | (() -> any)
  @type timezone :: :utc | :local | String.t
  @type schedule :: Crontab.CronExpression.t
  @type pids :: [{Node.t, pid}]

  @type t :: %__MODULE__{
    name: atom | nil,
    schedule: schedule | nil,
    task: task | nil,
    state: state,
    run_strategy: Quantum.RunStrategy.NodeList,
    overlap: boolean,
    pids: pids,
    timezone: timezone
  }

  @doc """
  Takes some config from a scheduler and returns a new job

  ### Examples

      iex> Acme.Scheduler.config
      ...> |> Quantum.Job.new
      %Quantum.Job{...}
  """
  @spec new(config :: Keyword.t) :: t
  def new(config) do
    {run_strategy_name, options} = Keyword.fetch!(config, :run_strategy)
    run_strategy = run_strategy_name.normalize_config!(options)

    job = %__MODULE__{}
    |> set_overlap(Keyword.fetch!(config, :overlap))
    |> set_timezone(Keyword.fetch!(config, :timezone))
    |> set_run_strategy(run_strategy)

    schedule = Keyword.fetch!(config, :schedule)
    if schedule do
      set_schedule(job, Quantum.Normalizer.normalize_schedule(schedule))
    else
      job
    end
  end

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
  @spec executable?(t, Node.t) :: boolean
  def executable?(job, node) do
    pid = Keyword.get(job.pids, node, nil)
    cond do
      job.state != :active    -> false # Do not execute inactive jobs
      job.overlap == true     -> true  # Job may overlap
      pid == nil              -> true  # Job has not been started
      is_alive?(pid)          -> false # Previous job is still running
      true                    -> true  # Previous job has finished
    end
  end

  @doc """
  Is job still running?
  """
  @spec is_alive?(pid) :: boolean
  def is_alive?(pid) do
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
  Sets a jobs run strategy.

  ### Parameters

    1. `job` - The job struct to modify
    2. `run_strategy` - The run strategy to set

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.run_strategy(%Quantum.RunStrategy.All{nodes: [:one, :two]})
      ...> |> Map.get(:run_strategy)
      [:one, :two]

  """
  @spec set_run_strategy(t, Quantum.RunStrategy.NodeList) :: t
  def set_run_strategy(job = %__MODULE__{}, run_strategy), do: Map.put(job, :run_strategy, run_strategy)

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
