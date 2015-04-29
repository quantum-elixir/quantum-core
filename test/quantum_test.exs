defmodule QuantumTest do
  use ExUnit.Case

  test "check hourly" do
    Quantum.execute(:"0 * * * *", fn -> IO.puts("OK") end, %{ d: { 2015, 12, 31 }, h: 12, m: 0, w: 1 } )
  end

  test "parse */5" do
    Quantum.execute(:"*/5 * * * *", fn -> IO.puts("OK") end, %{ d: { 2015, 12, 31 }, h: 12, m: 0, w: 1 } )
  end

  test "parse 5" do
    Quantum.execute(:"5 * * * *", fn -> IO.puts("OK") end, %{ d: { 2015, 12, 31 }, h: 12, m: 5, w: 1 } )
  end
  
  test "counter example" do
    Quantum.execute(:"5 * * * *", fn -> IO.puts("FAIL") end, %{ d: { 2015, 12, 31 }, h: 12, m: 0, w: 1 } )
  end
  
end
