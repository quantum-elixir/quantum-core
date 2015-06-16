defmodule Quantum.MatcherTest do
  use ExUnit.Case

  import Quantum.Matcher

  test "should always match" do
    assert match("*", nil, nil, nil) == true
  end

  test "should match list" do
    assert match("1,2",      1, 0, 59) == true
    assert match("1,2",      2, 0, 59) == true
    assert match("1,2",      3, 0, 59) == false
    assert match("*/20,30",  0, 0, 59) == true
    assert match("*/20,30", 20, 0, 59) == true
    assert match("*/20,30", 30, 0, 59) == true
    assert match("*/20,30", 40, 0, 59) == true
    assert match("*/20,30", 50, 0, 59) == false
  end

end
