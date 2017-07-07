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

    * `:global` - When you have a cluster of nodes, you may not
      want same jobs to be generated on every single node, e.g.
      jobs involving db changes.

      In this case, you may choose to run Quantum as a global process,
      thus preventing same job being run multiple times because of
      it being generated on multiple nodes. With the following
      configuration, Quantum will be run as a globally unique
      process across the cluster.

    * `:schedule` - Default schedule of new Job

    * `:run_strategy` - Default Run Strategy of new Job

    * `:overlap` - Default overlap of new Job,

    * `:timezone` - Default timezone of new Job

  """

  alias Quantum.Job
  alias Quantum.Normalizer

  @opaque t :: module

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts, moduledoc: @moduledoc] do
      @moduledoc moduledoc
      |> String.replace(~r/MyApp\.Scheduler/, Enum.join(Module.split(__MODULE__), "."))
      |> String.replace(~r/:my_app/, Atom.to_string(Keyword.fetch!(opts, :otp_app)))

      @behaviour Quantum.Scheduler

      @otp_app Keyword.fetch!(opts, :otp_app)

      def config(custom \\ []) do
        Quantum.scheduler_config(__MODULE__, @otp_app, custom)
      end

      defp __runner__, do: Keyword.fetch!(config(), :runner)
      defp __timeout__, do: Keyword.fetch!(config(), :timeout)

      def start_link(opts \\ []) do
        Quantum.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def stop(pid, timeout \\ 5000) do
        Supervisor.stop(pid, :normal, timeout)
      end

      def add_job(server \\ __runner__(), job)
      def add_job(server, job = %Job{name: nil}) do
        GenServer.call(server, {:add, {nil, job}}, __timeout__())
      end
      def add_job(server, job = %Job{name: name}) do
        if find_job(name) do
          :error
        else
          GenServer.call(server, {:add, {name, job}}, __timeout__())
        end
      end

      def add_job(server, {%Crontab.CronExpression{} = schedule, task}) when is_tuple(task) or is_function(task, 0) do
        job = new_job()
        |> Job.set_schedule(schedule)
        |> Job.set_task(task)
        add_job(server, job)
      end

      def new_job(config \\ config()) do
        {run_strategy_name, options} = Keyword.fetch!(config, :run_strategy)
        run_strategy = run_strategy_name.normalize_config!(options)

        job = %Job{}
        |> Job.set_overlap(Keyword.fetch!(config, :overlap))
        |> Job.set_timezone(Keyword.fetch!(config, :timezone))
        |> Job.set_run_strategy(run_strategy)

        schedule = Keyword.fetch!(config, :schedule)
        if schedule do
          Job.set_schedule(job, Quantum.Normalizer.normalize_schedule(schedule))
        else
          job
        end
      end

      def deactivate_job(server \\ __runner__(), name) do
        GenServer.call(server, {:change_state, name, :inactive}, __timeout__())
      end

      def activate_job(server \\ __runner__(), name) do
        GenServer.call(server, {:change_state, name, :active}, __timeout__())
      end

      def find_job(server \\ __runner__(), name) do
        GenServer.call(server, {:find_job, name}, __timeout__())
      end

      def delete_job(server \\ __runner__(), name) do
        GenServer.call(server, {:delete, name}, __timeout__())
      end

      def delete_all_jobs(server \\ __runner__()) do
        GenServer.call(server, {:delete_all}, __timeout__())
      end

      def jobs(server \\ __runner__()) do
        GenServer.call(server, :jobs, __timeout__())
      end
    end
  end

  @optional_callbacks init: 1

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
  A callback executed when the quantum starts.

  It takes the quantum configuration that is stored in the application
  environment, and may change it to suit the application business.

  It must return the updated list of configuration
  """
  @callback init(config :: Keyword.t) :: Keyword.t

  @doc """
  Shuts down the quantum represented by the given pid.
  """
  @callback stop(pid, timeout) :: :ok

  @doc """
  Creates a new Job. The job can be added by calling `add_job/1`.
  """
  @callback new_job() :: Quantum.Job.t

  @doc """
  Adds a new job
  """
  @callback add_job(GenServer.server, Quantum.Job.t | {Crontab.CronExpression.t, Job.task}) :: :ok | :error

  @doc """
  Deactivates a job by name
  """
  @callback deactivate_job(GenServer.server, atom) :: :ok | {:error, :not_found}

  @doc """
  Activates a job by name
  """
  @callback activate_job(GenServer.server, atom) :: :ok | {:error, :not_found}

  @doc """
  Resolves a job by name
  """
  @callback find_job(GenServer.server, atom) :: Quantum.Job.t | nil

  @doc """
  Deletes a job by name
  """
  @callback delete_job(GenServer.server, atom) :: :ok | {:error, :not_found}

  @doc """
  Deletes all jobs
  """
  @callback delete_all_jobs(GenServer.server) :: :ok

  @doc """
  Returns the list of currently defined jobs
  """
  @callback jobs(GenServer.server) :: [Quantum.Job.t]
end
