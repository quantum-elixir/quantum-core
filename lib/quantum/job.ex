defmodule Quantum.Job do
  @moduledoc """
  This Struct defines a Job.

  ## Usage

  The struct should never be defined by hand. Use `c:Quantum.new_job/1` to create a new job and use the setters mentioned
  below to mutate the job.

  This is to ensure type safety.

  """

  alias Crontab.CronExpression

  @enforce_keys [:name, :run_strategy, :overlap, :timezone]

  defstruct [
    :run_strategy,
    :overlap,
    :timezone,
    :name,
    schedule: nil,
    task: nil,
    state: :active
  ]

  @type name :: atom | reference()
  @type state :: :active | :inactive
  @type task :: {atom, atom, [any]} | (() -> any)
  @type timezone :: :utc | String.t()
  @type schedule :: Crontab.CronExpression.t()

  @type t :: %__MODULE__{
          name: name,
          schedule: schedule | nil,
          task: task | nil,
          state: state,
          run_strategy: Quantum.RunStrategy.NodeList,
          overlap: boolean,
          timezone: timezone
        }

  # Takes some config from a scheduler and returns a new job
  # Do not use directly, use `Scheduler.new_job/1` instead.
  @doc false
  @spec new(config :: Keyword.t()) :: t
  def new(config) do
    Enum.reduce(
      [
        {&set_name/2, Keyword.get(config, :name, make_ref())},
        {&set_overlap/2, Keyword.fetch!(config, :overlap)},
        {&set_run_strategy/2, Keyword.fetch!(config, :run_strategy)},
        {&set_schedule/2, Keyword.get(config, :schedule)},
        {&set_state/2, Keyword.fetch!(config, :state)},
        {&set_task/2, Keyword.get(config, :task)},
        {&set_timezone/2, Keyword.fetch!(config, :timezone)}
      ],
      %__MODULE__{name: nil, run_strategy: nil, overlap: nil, timezone: nil},
      fn
        {_fun, nil}, acc -> acc
        {fun, value}, acc -> fun.(acc, value)
      end
    )
  end

  @doc """
  Sets a job's name.

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
  def set_name(%__MODULE__{} = job, name) when is_atom(name), do: Map.put(job, :name, name)
  def set_name(%__MODULE__{} = job, name) when is_reference(name), do: Map.put(job, :name, name)

  @doc """
  Sets a job's schedule.

  ### Parameters

    1. `job` - The job struct to modify
    2. `schedule` - The schedule to set. May only be of type `%Crontab.CronExpression{}`

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("*/7"))
      ...> |> Map.get(:schedule)
      Crontab.CronExpression.Parser.parse!("*/7")

  """
  @spec set_schedule(t, CronExpression.t()) :: t
  def set_schedule(%__MODULE__{} = job, %CronExpression{} = schedule),
    do: %{job | schedule: schedule}

  @doc """
  Sets a job's task.

  ### Parameters

    1. `job` - The job struct to modify
    2. `task` - The function to be performed, ex: `{Heartbeat, :send, []}` or `fn -> :something end`

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_task({Backup, :backup, []})
      ...> |> Map.get(:task)
      {Backup, :backup, []}

  """
  @spec set_task(t, task) :: t
  def set_task(%__MODULE__{} = job, {module, function, args} = task)
      when is_atom(module) and is_atom(function) and is_list(args),
      do: Map.put(job, :task, task)

  def set_task(%__MODULE__{} = job, task) when is_function(task, 0), do: Map.put(job, :task, task)

  @doc """
  Sets a job's state.

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
  def set_state(%__MODULE__{} = job, :active), do: Map.put(job, :state, :active)
  def set_state(%__MODULE__{} = job, :inactive), do: Map.put(job, :state, :inactive)

  @doc """
  Sets a job's run strategy.

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
  def set_run_strategy(%__MODULE__{} = job, run_strategy),
    do: Map.put(job, :run_strategy, run_strategy)

  @doc """
  Sets a job's overlap.

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
  def set_overlap(%__MODULE__{} = job, overlap?) when is_boolean(overlap?),
    do: Map.put(job, :overlap, overlap?)

  @doc """
  Sets a job's timezone.

  ### Parameters

    1. `job` - The job struct to modify
    2. `timezone` - The timezone to set.

  ### Examples

      iex> Acme.Scheduler.new_job()
      ...> |> Quantum.Job.set_timezone("Europe/Zurich")
      ...> |> Map.get(:timezone)
      "Europe/Zurich"

  """
  @spec set_timezone(t, String.t() | :utc) :: t
  def set_timezone(%__MODULE__{} = job, timezone), do: Map.put(job, :timezone, timezone)
end
