defmodule Quantum do
  @moduledoc """
  Defines a quantum runner.

  When used, the quantum runner expects the `:otp_app` as option.
  The `:otp_app` should point to an OTP application that has
  the quantum rinner configuration. For example, the quantum runner:

      defmodule MyApp.Quantum do
        use Quantum, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.Quantum,
        jobs: [
          "@daily": &Backup.backup/0,
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
  """

  @type t :: module

  @typedoc """
  A cron expression
  """
  @type expr :: String.t | Atom

  @typedoc """
  A function/0 to be called when cron expression matches
  """
  @type fun0 :: (() -> Type)

  @typedoc """
  A job is defined by a cron expression and a task
  """
  @type job :: {atom, Job.t}

  @typedoc """
  A job options can be defined as list or map
  """
  @type opts :: list | map | fun0

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Quantum

      @otp_app Keyword.fetch!(opts, :otp_app)

      def config do
        {:ok, config} = Quantum.Supervisor.runtime_config(:dry_run, __MODULE__, @otp_app, [])
        config
      end

      defp __timeout__, do: Keyword.fetch!(config(), :timeout)
      defp __scheduler__, do: Keyword.fetch!(config(), :scheduler)

      def start_link(opts \\ []) do
        Quantum.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def stop(pid, timeout \\ 5000) do
        Supervisor.stop(pid, :normal, timeout)
      end

      def add_job(job) do
        GenServer.call(__scheduler__(), {:add, Quantum.Normalizer.normalize({nil, job})}, __timeout__())
      end

      def add_job(expr, job) do
        {name, job} = Quantum.Normalizer.normalize({expr, job})
        if name && find_job(name) do
          :error
        else
          GenServer.call(__scheduler__(), {:add, {name, job}}, __timeout__())
        end
      end

      def deactivate_job(n) do
        GenServer.call(__scheduler__(), {:change_state, n, :inactive}, __timeout__())
      end

      def activate_job(n) do
        GenServer.call(__scheduler__(), {:change_state, n, :active}, __timeout__())
      end

      def find_job(name) do
        GenServer.call(__scheduler__(), {:find_job, name}, __timeout__())
      end

      def delete_job(name) do
        GenServer.call(__scheduler__(), {:delete, name}, __timeout__())
      end

      def delete_all_jobs do
        GenServer.call(__scheduler__(), {:delete_all}, __timeout__())
      end

      def jobs do
        GenServer.call(__scheduler__(), :jobs, __timeout__())
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
  Adds a new unnamed job
  """
  @callback add_job(job) :: :ok

  @doc """
  Adds a new named job
  """
  @callback add_job(expr, job) :: :ok | :error

  @doc """
  Deactivates a job by name
  """
  @callback deactivate_job(expr) :: :ok

  @doc """
  Activates a job by name
  """
  @callback activate_job(expr) :: :ok

  @doc """
  Resolves a job by name
  """
  @callback find_job(expr) :: job

  @doc """
  Deletes a job by name
  """
  @callback delete_job(expr) :: job

  @doc """
  Deletes all jobs
  """
  @callback delete_all_jobs :: :ok

  @doc """
  Returns the list of currently defined jobs
  """
  @callback jobs :: [job]
end
