defmodule QuantumTest do
  use ExUnit.Case

  test "check hourly" do
    Quantum.execute("0 * * * *", fn -> IO.puts("OK") end, %{d: {2015, 12, 31 }, h: 12, m: 0, w: 1})
  end

  test "parse */5" do
    Quantum.execute("*/5 * * * *", fn -> IO.puts("OK") end, %{d: {2015, 12, 31 }, h: 12, m: 0, w: 1})
  end

  test "parse 5" do
    Quantum.execute("5 * * * *", fn -> IO.puts("OK") end, %{d: {2015, 12, 31 }, h: 12, m: 5, w: 1})
  end
  
  test "counter example" do
    Quantum.execute("5 * * * *", fn -> IO.puts("FAIL") end, %{d: {2015, 12, 31 }, h: 12, m: 0, w: 1})
  end
  
  test "parse" do
    assert Quantum.parse("0/20", 0, 59) == [0]
    assert Quantum.parse("10-15", 0, 59) == [10, 11, 12, 13, 14, 15]
    assert Quantum.parse("55-100", 0, 59) == [55, 56, 57, 58, 59]
    assert Quantum.parse("1,1,2,3,5,8" |> String.split(","), 0, 59) == [1, 2, 3, 5, 8]
    assert Quantum.parse("*/20,30" |> String.split(","), 0, 59) == [0, 20, 30, 40]
    assert Quantum.parse("55-5", 0, 59) == [0, 1, 2, 3, 4, 5, 55, 56, 57, 58, 59]
  end

  test "daily" do
    Quantum.execute(:"@DAILY", fn -> IO.puts("FAIL") end, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1})
  end

  test "adding a job at run time" do
    spec = "1 * * * *"
    job = fn -> :ok end
    :ok = Quantum.add_job(spec, job)
    assert [{spec, job}] == Quantum.jobs
  end
  
end
