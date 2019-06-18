defmodule Quantum.NodeSelectorBroadcasterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Quantum.CaptureLogExtend

  alias Quantum.ExecutionBroadcaster.Event, as: ExecuteEvent
  alias Quantum.Job
  alias Quantum.NodeSelectorBroadcaster
  alias Quantum.NodeSelectorBroadcaster.Event
  alias Quantum.NodeSelectorBroadcaster.StartOpts
  alias Quantum.RunStrategy.All
  alias Quantum.{TestConsumer, TestProducer}

  doctest NodeSelectorBroadcaster

  defmodule TestScheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :job_broadcaster_test
  end

  setup _ do
    task_supervisor =
      start_supervised!({Task.Supervisor, [name: Module.concat(__MODULE__, TaskSupervisor)]})

    producer = start_supervised!({TestProducer, []})

    {broadcaster, _} =
      capture_log_with_return(fn ->
        start_supervised!(
          {NodeSelectorBroadcaster,
           %StartOpts{
             name: __MODULE__,
             execution_broadcaster_reference: producer,
             task_supervisor_reference: task_supervisor
           }}
        )
      end)

    start_supervised!({TestConsumer, [broadcaster, self()]})

    {:ok, %{producer: producer, broadcaster: broadcaster}}
  end

  describe "execute" do
    test "schedules execution", %{
      producer: producer
    } do
      caller = self()

      job =
        TestScheduler.new_job()
        |> Job.set_task(fn -> send(caller, :executed) end)

      TestProducer.send(producer, %ExecuteEvent{job: job})

      node_self = Node.self()
      assert_receive {:received, %Event{job: ^job, node: ^node_self}}
    end

    test "doesn't execute on invalid node", %{
      producer: producer
    } do
      node = :"invalid-name@invalid-host"

      job =
        TestScheduler.new_job()
        |> Job.set_run_strategy(%All{nodes: [node]})

      assert capture_log(fn ->
               TestProducer.send(producer, %ExecuteEvent{job: job})

               refute_receive %Event{}
             end) =~
               "Node #{inspect(node)} is not running. Job #{inspect(job.name)} could not be executed."
    end
  end

  def send(caller) do
    send(caller, :executed)
  end
end
