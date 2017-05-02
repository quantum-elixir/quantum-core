defmodule Quantum.Scheduler do
  @moduledoc """
  Defines a quantum Scheduler.

  When used, the quantum scheduler expects the `:otp_app` as option.
  The `:otp_app` should point to an OTP application that has
  the quantum rinner configuration. For example, the quantum scheduler:

      defmodule MyApp.Scheduler do
        use Quantum.Scheduler, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.Scheduler,
        jobs: [
          {"@daily", {Backup, :backup, []},
        ]

  ## Configuration:

    * `:timeout` - Sometimes, you may come across GenServer
      timeout errors esp. when you have too many jobs or high
      load. The default GenServer.call timeout is 5000.

    * `:jobs` - list of cron jobs to execute

    * `:global?` - When you have a cluster of nodes, you may not
      want same jobs to be generated on every single node, e.g.
      jobs involving db changes.

      In this case, you may choose to run Quantum as a global process,
      thus preventing same job being run multiple times because of
      it being generated on multiple nodes. With the following
      configuration, Quantum will be run as a globally unique
      process across the cluster.

    * `:default_schedule` - Default Schedule of new Job

    * `:default_overlap` - Default Overlap of new Job

    * `:default_timezone` - Default Timezone of new Job

    * `:default_nodes` - Default Nodes of new Job
  """

  alias Quantum.Job

  @opaque t :: module

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Quantum.Scheduler

      @otp_app Keyword.fetch!(opts, :otp_app)

      def config do
        {:ok, config} = Quantum.Supervisor.runtime_config(:dry_run, __MODULE__, @otp_app, [])
        config
      end

      defp __timeout__, do: Keyword.fetch!(config(), :timeout)
      defp __runnner__, do: Keyword.fetch!(config(), :runner)

      def start_link(opts \\ []) do
        Quantum.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def stop(pid, timeout \\ 5000) do
        Supervisor.stop(pid, :normal, timeout)
      end

      def add_job(job = %Job{name: nil}) do
        GenServer.call(__runnner__(), {:add, {nil, job}}, __timeout__())
      end
      def add_job(job = %Job{name: name}) do
        if find_job(name) do
          :error
        else
          GenServer.call(__runnner__(), {:add, {name, job}}, __timeout__())
        end
      end

      def add_job(schedule = %Crontab.CronExpression{}, task) when is_tuple(task) or is_function(task, 0) do
        new_job()
        |> Job.set_schedule(schedule)
        |> Job.set_task(task)
        |> add_job
      end

      def new_job(config \\ config()) do
        job = %Job{}
        |> Job.set_overlap(Keyword.fetch!(config, :default_overlap))
        |> Job.set_timezone(Keyword.fetch!(config, :default_timezone))
        |> Job.set_run_strategy(Keyword.fetch!(config, :default_run_strategy))

        if Keyword.fetch!(config, :default_schedule) do
          Job.set_schedule(job, Keyword.fetch!(config, :default_schedule))
        else
          job
        end
      end

      def deactivate_job(name) do
        GenServer.call(__runnner__(), {:change_state, name, :inactive}, __timeout__())
      end

      def activate_job(name) do
        GenServer.call(__runnner__(), {:change_state, name, :active}, __timeout__())
      end

      def find_job(name) do
        GenServer.call(__runnner__(), {:find_job, name}, __timeout__())
      end

      def delete_job(name) do
        GenServer.call(__runnner__(), {:delete, name}, __timeout__())
      end

      def delete_all_jobs do
        GenServer.call(__runnner__(), {:delete_all}, __timeout__())
      end

      def jobs do
        GenServer.call(__runnner__(), :jobs, __timeout__())
      end
    end
  end

  @optional_callbacks init: 2

  @doc """
  Returns the configuration stored in the `:otp_app` environment.
  """
  @callback config() :: Keyword.t

  @doc """
  Starts supervision and return `{:ok, pid}`
  or just `:ok` if nothing needs to be done.

  Returns `{:error, {:already_started, pid}}` if the repo is already
  started or `{:error, term}` in case anything else goes wrong.

  ## Options

  See the configuration in the moduledoc for options.
  """
  @callback start_link(opts :: Keyword.t) :: {:ok, pid} |
                            {:error, {:already_started, pid}} |
                            {:error, term}

  @doc """
  A callback executed when the quantum starts or when configuration is read.

  The first argument is the context the callback is being invoked. If it
  is called because the Repo supervisor is starting, it will be `:supervisor`.
  It will be `:dry_run` if it is called for reading configuration without
  actually starting a process.

  The second argument is the quantum configuration as stored in the
  application environment. It must return `{:ok, keyword}` with the updated
  list of configuration or `:ignore` (only in the `:supervisor` case).
  """
  @callback init(source :: :supervisor | :dry_run, config :: Keyword.t) :: {:ok, Keyword.t} | :ignore

  @doc """
  Shuts down the quantum represented by the given pid.
  """
  @callback stop(pid, timeout) :: :ok

  @doc """
  Creates a new Job. The job can be added by calling `add_job/1`.
  """
  @callback new_job() :: Quantum.Job.t

  @doc """
  Adds a new unnamed job
  """
  @callback add_job(Quantum.Job.t) :: :ok

  @doc """
  Adds a new named job
  """
  @callback add_job(Crontab.CronExpression.t, Job.task) :: :ok | :error

  @doc """
  Deactivates a job by name
  """
  @callback deactivate_job(atom) :: :ok | {:error, :not_found}

  @doc """
  Activates a job by name
  """
  @callback activate_job(atom) :: :ok | {:error, :not_found}

  @doc """
  Resolves a job by name
  """
  @callback find_job(atom) :: Quantum.Job.t | nil

  @doc """
  Deletes a job by name
  """
  @callback delete_job(atom) :: :ok | {:error, :not_found}

  @doc """
  Deletes all jobs
  """
  @callback delete_all_jobs :: :ok

  @doc """
  Returns the list of currently defined jobs
  """
  @callback jobs :: [Quantum.Job.t]
end
