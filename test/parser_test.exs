defmodule Quantum.ParserTest do
  use ExUnit.Case

  import Quantum.Parser

  test "parse" do
    assert parse("0/20", 0, 59) == [0]
    assert parse("15-45/5", 0, 59) == [15, 20, 25, 30, 35, 40, 45]
    assert parse("10-15", 0, 59) == [10, 11, 12, 13, 14, 15]
    assert parse("55-100", 0, 59) == [55, 56, 57, 58, 59]
    assert parse("55-5", 0, 59) == [0, 1, 2, 3, 4, 5, 55, 56, 57, 58, 59]
  end

end
