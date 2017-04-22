defmodule Qauntum.TimerTest do
  @moduledoc false
  use ExUnit.Case

  alias Quantum.Timer

  describe "tick/0" do
    test "sends tick message" do
      Timer.tick()

      # Should be sent after a few ms and not instantly
      refute_received :tick

      # Should Receive tick after max 999 ms
      assert_receive :tick, 999
    end

    test "gives back last date with reset ms" do
      now = NaiveDateTime.utc_now
      # Reset MS
      |> NaiveDateTime.to_erl
      |> NaiveDateTime.from_erl!

      assert now == Timer.tick()
    end
  end
end
