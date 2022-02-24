defmodule Quantum do
  use TelemetryRegistry

  telemetry_event(%{
    event: [:quantum, :job, :add],
    description: "dispatched when a job is added",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :update],
    description: "dispatched when a job is updated",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :delete],
    description: "dispatched when a job is deleted",
    measurements: "%{}",
    metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :start],
    description: "dispatched on job execution start",
    measurements: "%{system_time: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :stop],
    description: "dispatched on job execution end",
    measurements: "%{duration: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}"
  })

  telemetry_event(%{
    event: [:quantum, :job, :exception],
    description: "dispatched on job execution fail",
    measurements: "%{duration: integer()}",
    metadata:
      "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}"
  })

  @moduledoc """
  Defines a quantum Scheduler.

  When used, the quantum scheduler expects the `:otp_app` as option.
  The `:otp_app` should point to an OTP application that has
  the quantum runner configuration. For example, the quantum scheduler:

      defmodule MyApp.Scheduler do
        use Quantum, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.Scheduler,
        jobs: [
          {"@daily", {Backup, :backup, []}},
        ]

  ## Configuration:

    * `:clock_broadcaster_name` - GenServer name of clock broadcaster \\
      *(unstable, may break without major release until declared stable)*

    * `:execution_broadcaster_name` - GenServer name of execution broadcaster \\
      *(unstable, may break without major release until declared stable)*

    * `:executor_supervisor_name` - GenServer name of execution supervisor \\
      *(unstable, may break without major release until declared stable)*

    * `:debug_logging` - Turn on debug logging

    * `:jobs` - list of cron jobs to execute

    * `:job_broadcaster_name` - GenServer name of job broadcaster \\
      *(unstable, may break without major release until declared stable)*

    * `:name` - GenServer name of scheduler \\
      *(unstable, may break without major release until declared stable)*

    * `:node_selector_broadcaster_name` - GenServer name of node selector broadcaster \\
      *(unstable, may break without major release until declared stable)*

    * `:overlap` - Default overlap of new Job

    * `:otp_app` - Application where scheduler runs

    * `:run_strategy` - Default Run Strategy of new Job

    * `:schedule` - Default schedule of new Job

    * `:storage` - Storage to use for persistence

    * `:storage_name` - GenServer name of storage \\
      *(unstable, may break without major release until declared stable)*

    * `:supervisor_module` - Module to supervise scheduler \\
      Can be overwritten to supervise processes differently (for example for clustering) \\
      *(unstable, may break without major release until declared stable)*

    * `:task_registry_name` - GenServer name of task registry \\
      *(unstable, may break without major release until declared stable)*

    * `:task_supervisor_name` - GenServer name of task supervisor \\
      *(unstable, may break without major release until declared stable)*

    * `:timeout` - Sometimes, you may come across GenServer timeout errors
      esp. when you have too many jobs or high load. The default `GenServer.call/3`
      timeout is `5_000`.

    * `:timezone` - Default timezone of new Job

  ## Telemetry

  #{telemetry_docs()}

  ### Examples

      iex(1)> :telemetry_registry.discover_all(:quantum)
      :ok
      iex(2)> :telemetry_registry.spannable_events()
      [{[:quantum, :job], [:start, :stop, :exception]}]
      iex(3)> :telemetry_registry.list_events
      [
        {[:quantum, :job, :add], Quantum,
         %{
           description: "dispatched when a job is added",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :delete], Quantum,
         %{
           description: "dispatched when a job is deleted",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :exception], Quantum,
         %{
           description: "dispatched on job execution fail",
           measurements: "%{duration: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}"
         }},
        {[:quantum, :job, :start], Quantum,
         %{
           description: "dispatched on job execution start",
           measurements: "%{system_time: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}"
         }},
        {[:quantum, :job, :stop], Quantum,
         %{
           description: "dispatched on job execution end",
           measurements: "%{duration: integer()}",
           metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}"
         }},
        {[:quantum, :job, :update], Quantum,
         %{
           description: "dispatched when a job is updated",
           measurements: "%{}",
           metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
         }}
      ]
  """

  require Logger

  alias Quantum.{Job, Normalizer, RunStrategy.Random, Storage.Noop}

  @typedoc """
  Quantum Scheduler Implementation
  """
  @type t :: module

  @defaults [
    timeout: 5_000,
    schedule: nil,
    overlap: true,
    state: :active,
    timezone: :utc,
    run_strategy: {Random, :cluster},
    debug_logging: true,
    storage: Noop
  ]

  # Returns the configuration stored in the `:otp_app` environment.
  @doc false
  @callback config(Keyword.t()) :: Keyword.t()

  @doc """
  Starts supervision and return `{:ok, pid}`
  or just `:ok` if nothing needs to be done.

  Returns `{:error, {:already_started, pid}}` if the scheduler is already
  started or `{:error, term}` in case anything else goes wrong.

  ## Options

  See the configuration in the moduledoc for options.
  """
  @callback start_link(opts :: Keyword.t()) ::
              {:ok, pid}
              | {:error, {:already_started, pid}}
              | {:error, term}

  @doc """
  A callback executed when the quantum starts.

  It takes the quantum configuration that is stored in the application
  environment, and may change it to suit the application business.

  It must return the updated list of configuration
  """
  @callback init(config :: Keyword.t()) :: Keyword.t()

  @doc """
  Shuts down the quantum represented by the given pid.
  """
  @callback stop(server :: GenServer.server(), timeout) :: :ok

  @doc """
  Creates a new Job. The job can be added by calling `add_job/1`.

  ## Supported options

  * `name` - see `Quantum.Job.set_name/2`
  * `overlap` - see `Quantum.Job.set_overlap/2`
  * `run_strategy` - see `Quantum.Job.set_run_strategy/2`
  * `schedule` - see `Quantum.Job.set_schedule/2`
  * `state` - see `Quantum.Job.set_state/2`
  * `task` - see `Quantum.Job.set_task/2`
  * `timezone` - see `Quantum.Job.set_timezone/2`
  """
  @callback new_job(opts :: Keyword.t()) :: Quantum.Job.t()

  @doc """
  Adds a new job
  """
  @callback add_job(GenStage.stage(), Quantum.Job.t() | {Crontab.CronExpression.t(), Job.task()}) ::
              :ok

  @doc """
  Deactivates a job by name
  """
  @callback deactivate_job(GenStage.stage(), atom) :: :ok

  @doc """
  Activates a job by name
  """
  @callback activate_job(GenStage.stage(), atom) :: :ok

  @doc """
  Runs a job by name once
  """
  @callback run_job(GenStage.stage(), atom) :: :ok

  @doc """
  Resolves a job by name
  """
  @callback find_job(GenStage.stage(), atom) :: Quantum.Job.t() | nil

  @doc """
  Deletes a job by name
  """
  @callback delete_job(GenStage.stage(), atom) :: :ok

  @doc """
  Deletes all jobs
  """
  @callback delete_all_jobs(GenStage.stage()) :: :ok

  @doc """
  Returns the list of currently defined jobs
  """
  @callback jobs(GenStage.stage()) :: [Quantum.Job.t()]

  @doc false
  # Retrieves only scheduler related configuration.
  def scheduler_config(opts, scheduler, otp_app) do
    @defaults
    |> Keyword.merge(Application.get_env(otp_app, scheduler, []))
    |> Keyword.merge(opts)
    |> Keyword.put_new(:otp_app, otp_app)
    |> Keyword.put_new(:scheduler, scheduler)
    |> Keyword.put_new(:name, scheduler)
    |> update_in([:schedule], &Normalizer.normalize_schedule/1)
    |> Keyword.put_new(:task_supervisor_name, Module.concat(scheduler, TaskSupervisor))
    |> Keyword.put_new(:storage_name, Module.concat(scheduler, Storage))
    |> Keyword.put_new(:task_registry_name, Module.concat(scheduler, TaskRegistry))
    |> Keyword.put_new(:clock_broadcaster_name, Module.concat(scheduler, ClockBroadcaster))
    |> Keyword.put_new(:job_broadcaster_name, Module.concat(scheduler, JobBroadcaster))
    |> Keyword.put_new(
      :execution_broadcaster_name,
      Module.concat(scheduler, ExecutionBroadcaster)
    )
    |> Keyword.put_new(
      :node_selector_broadcaster_name,
      Module.concat(scheduler, NodeSelectorBroadcaster)
    )
    |> Keyword.put_new(:executor_supervisor_name, Module.concat(scheduler, ExecutorSupervisor))
    |> Kernel.then(fn config ->
      Keyword.update(config, :jobs, [], fn jobs ->
        jobs
        |> Enum.map(&Normalizer.normalize(scheduler.__new_job__([], config), &1))
        |> remove_jobs_with_duplicate_names(scheduler)
      end)
    end)
    |> Keyword.put_new(:supervisor_module, Quantum.Supervisor)
    |> Keyword.put_new(:name, Quantum.Supervisor)
  end

  defp remove_jobs_with_duplicate_names(job_list, scheduler) do
    job_list
    |> Enum.reduce(%{}, fn %Job{name: name} = job, acc ->
      if Enum.member?(Map.keys(acc), name) do
        Logger.warn(
          "Job with name '#{name}' of scheduler '#{scheduler}' not started due to duplicate job name"
        )

        acc
      else
        Map.put_new(acc, name, job)
      end
    end)
    |> Map.values()
  end

  defmacro __using__(opts) do
    quote bind_quoted: [behaviour: __MODULE__, opts: opts, moduledoc: @moduledoc],
          location: :keep do
      @otp_app Keyword.fetch!(opts, :otp_app)
      @moduledoc moduledoc
                 |> String.replace(~r/MyApp\.Scheduler/, Enum.join(Module.split(__MODULE__), "."))
                 |> String.replace(~r/:my_app/, ":" <> Atom.to_string(@otp_app))

      @behaviour behaviour

      @doc false
      @impl behaviour
      def config(opts \\ []) do
        Quantum.scheduler_config(opts, __MODULE__, @otp_app)
      end

      defp __job_broadcaster__ do
        config() |> Keyword.fetch!(:job_broadcaster_name)
      end

      defp __timeout__, do: Keyword.fetch!(config(), :timeout)

      @impl behaviour
      def start_link(opts \\ []) do
        opts = config(opts)
        Keyword.fetch!(opts, :supervisor_module).start_link(__MODULE__, opts)
      end

      @impl behaviour
      def init(opts) do
        opts
      end

      @impl behaviour
      def stop(server \\ __MODULE__, timeout \\ 5000) do
        Supervisor.stop(server, :normal, timeout)
      end

      @impl behaviour
      def add_job(server \\ __job_broadcaster__(), job)

      def add_job(server, %Job{name: name} = job) do
        GenStage.cast(server, {:add, job})
      end

      def add_job(server, {%Crontab.CronExpression{} = schedule, task})
          when is_tuple(task) or is_function(task, 0) do
        job =
          new_job()
          |> Job.set_schedule(schedule)
          |> Job.set_task(task)

        add_job(server, job)
      end

      @impl behaviour
      def new_job(opts \\ []), do: __new_job__(opts, config())

      @doc false
      def __new_job__(opts, config) do
        config
        |> Keyword.take([:overlap, :schedule, :state, :timezone, :run_strategy])
        |> Keyword.merge(opts)
        |> Keyword.update!(:run_strategy, fn
          {module, options} when is_atom(module) -> module.normalize_config!(options)
          module when is_atom(module) -> module.normalize_config!(nil)
          %_struct{} = run_strategy -> run_strategy
        end)
        |> Job.new()
      end

      @impl behaviour
      def deactivate_job(server \\ __job_broadcaster__(), name)
          when is_atom(name) or is_reference(name) do
        GenStage.cast(server, {:change_state, name, :inactive})
      end

      @impl behaviour
      def activate_job(server \\ __job_broadcaster__(), name)
          when is_atom(name) or is_reference(name) do
        GenStage.cast(server, {:change_state, name, :active})
      end

      @impl behaviour
      def run_job(server \\ __job_broadcaster__(), name)
          when is_atom(name) or is_reference(name) do
        GenStage.cast(server, {:run_job, name})
      end

      @impl behaviour
      def find_job(server \\ __job_broadcaster__(), name)
          when is_atom(name) or is_reference(name) do
        GenStage.call(server, {:find_job, name}, __timeout__())
      end

      @impl behaviour
      def delete_job(server \\ __job_broadcaster__(), name)
          when is_atom(name) or is_reference(name) do
        GenStage.cast(server, {:delete, name})
      end

      @impl behaviour
      def delete_all_jobs(server \\ __job_broadcaster__()) do
        GenStage.cast(server, :delete_all)
      end

      @impl behaviour
      def jobs(server \\ __job_broadcaster__()) do
        GenStage.call(server, :jobs, __timeout__())
      end

      spec = [
        id: opts[:id] || __MODULE__,
        start: Macro.escape(opts[:start]) || quote(do: {__MODULE__, :start_link, [opts]}),
        restart: opts[:restart] || :permanent,
        type: :worker
      ]

      @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{unquote_splicing(spec)}
      end

      defoverridable child_spec: 1, config: 0, config: 1, init: 1
    end
  end
end
