defmodule Quantum.MatcherTest do
  use ExUnit.Case

  import Quantum.Matcher

  test "should always match" do
    assert match("*", nil, nil, nil) == true
  end

end
