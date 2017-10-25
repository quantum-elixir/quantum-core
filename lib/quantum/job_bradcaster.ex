defmodule Quantum.JobBroadcaster do
  @moduledoc """
  This Module is here to broadcast added / removed tabs into the execution pipeline.
  """

  use GenStage

  alias Quantum.{Job, Util}

  @doc """
  Start Job Broadcaster

  ### Arguments

   * `name` - Name of the GenStage
   * `jobs` - Array of `Quantum.Job`

  """
  @spec start_link(GenServer.server(), [Job.t()]) :: GenServer.on_start()
  def start_link(name, jobs) do
    __MODULE__
    |> GenStage.start_link(jobs, name: name)
    |> Util.start_or_link()
  end

  @doc false
  @spec child_spec({GenServer.server(), [Job.t()]}) :: Supervisor.child_spec()
  def child_spec({name, jobs}) do
    %{super([]) | start: {__MODULE__, :start_link, [name, jobs]}}
  end

  @doc false
  def init(jobs) do
    buffer =
      jobs
      |> Enum.filter(&(&1.state == :active))
      |> Enum.map(fn job -> {:add, job} end)

    state =
      %{}
      |> Map.put(:jobs, Enum.reduce(jobs, %{}, fn job, acc -> Map.put(acc, job.name, job) end))
      |> Map.put(:buffer, buffer)

    {:producer, state}
  end

  def handle_demand(demand, %{buffer: buffer} = state) do
    {to_send, remaining} = Enum.split(buffer, demand)

    {:noreply, to_send, %{state | buffer: remaining}}
  end

  def handle_cast({:add, %Job{state: :active} = job}, state) do
    {:noreply, [{:add, job}], put_in(state[:jobs][job.name], job)}
  end

  def handle_cast({:add, %Job{state: :inactive} = job}, state) do
    {:noreply, [], put_in(state[:jobs][job.name], job)}
  end

  def handle_cast({:delete, name}, %{jobs: jobs} = state) do
    cond do
      !Map.has_key?(jobs, name) ->
        {:noreply, [], state}

      Map.fetch!(jobs, name).state == :active ->
        {:noreply, [{:remove, name}], %{state | jobs: Map.delete(jobs, name)}}

      true ->
        {:noreply, [], state}
    end
  end

  def handle_cast({:change_state, name, new_state}, %{jobs: jobs} = state) do
    job = Map.fetch!(jobs, name)
    old_state = job.state

    jobs = Map.update!(jobs, name, &Job.set_state(&1, new_state))

    case new_state do
      ^old_state ->
        {:noreply, [], state}

      :active ->
        {:noreply, [{:add, %{job | state: new_state}}], %{state | jobs: jobs}}

      :inactive ->
        {:noreply, [{:remove, job.name}], %{state | jobs: jobs}}
    end
  rescue
    KeyError ->
      {:noreply, [], state}
  end

  def handle_cast(:delete_all, %{jobs: jobs} = state) do
    messages =
      jobs
      |> Enum.filter(fn
           {_name, %Job{state: :active}} -> true
           {_name, _job} -> false
         end)
      |> Enum.map(fn {name, _job} -> {:remove, name} end)

    {:noreply, messages, %{state | jobs: %{}}}
  end

  def handle_call(:jobs, _, %{jobs: jobs} = state), do: {:reply, Map.to_list(jobs), [], state}

  def handle_call({:find_job, name}, _, %{jobs: jobs} = state),
    do: {:reply, Map.get(jobs, name), [], state}
end
