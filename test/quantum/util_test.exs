defmodule Quantum.UtilTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantum.Util

  doctest Util

  describe "start_or_link/1" do
    test "passthrough unknown" do
      assert :foo == Util.start_or_link(:foo)
    end

    test "make already started error success" do
      pid = self()
      assert {:ok, pid} == Util.start_or_link({:error, {:already_started, pid}})
    end
  end
end
