defmodule Quantum.TestConsumer do
  @moduledoc false

  use GenStage

  def start_link(producer, target) do
    GenStage.start_link(__MODULE__, {producer, target})
  end

  def child_spec([producer, target]) do
    %{super([]) | start: {__MODULE__, :start_link, [producer, target]}}
  end

  def init({producer, owner}) do
    {:consumer, owner, subscribe_to: [producer]}
  end

  def handle_events(events, _from, owner) do
    for event <- events do
      send(owner, {:received, event})
    end

    {:noreply, [], owner}
  end
end
