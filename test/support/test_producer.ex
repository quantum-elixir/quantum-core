defmodule Quantum.TestProducer do
  @moduledoc false

  use GenStage

  def start_link do
    GenStage.start_link(__MODULE__, nil)
  end

  @doc false
  def child_spec(_) do
    %{super([]) | start: {__MODULE__, :start_link, []}}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def send(stage, message) do
    GenStage.cast(stage, message)
  end

  def init(_) do
    {:producer, nil}
  end

  def handle_cast(message, state) do
    {:noreply, [message], state}
  end
end
