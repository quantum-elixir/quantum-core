defmodule QuantumTest do
  use ExUnit.Case

  defp ok, do: :ok

  test "check minutely" do
    assert Quantum.execute("* * * * *", &ok/0, %{}) == :ok
  end

  test "check hourly" do
    assert Quantum.execute("0 * * * *", &ok/0, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert Quantum.execute("0 * * * *", &ok/0, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
    assert Quantum.execute("@hourly",   &ok/0, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert Quantum.execute("@hourly",   &ok/0, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
  end

  test "check daily" do
    assert Quantum.execute("0 0 * * *", &ok/0, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert Quantum.execute("0 0 * * *", &ok/0, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
    assert Quantum.execute("@daily",    &ok/0, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert Quantum.execute("@daily",    &ok/0, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
  end

  test "check weekly" do
    assert Quantum.execute("0 0 * * 0", &ok/0, %{d: {2015, 12, 31}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("0 0 * * 0", &ok/0, %{d: {2015, 12, 31}, h: 0, m: 1, w: 0}) == false
    assert Quantum.execute("@weekly",   &ok/0, %{d: {2015, 12, 31}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("@weekly",   &ok/0, %{d: {2015, 12, 31}, h: 0, m: 1, w: 0}) == false
  end

  test "check monthly" do
    assert Quantum.execute("0 0 1 * *", &ok/0, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("0 0 1 * *", &ok/0, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
    assert Quantum.execute("@monthly",  &ok/0, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("@monthly",  &ok/0, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "check yearly" do
    assert Quantum.execute("0 0 1 1 *", &ok/0, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("0 0 1 1 *", &ok/0, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
    assert Quantum.execute("@yearly",   &ok/0, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert Quantum.execute("@yearly",   &ok/0, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "parse */5" do
    assert Quantum.execute("*/5 * * * *", &ok/0, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
  end

  test "parse 5" do
    assert Quantum.execute("5 * * * *",  &ok/0, %{d: {2015, 12, 31}, h: 12, m: 5, w: 1}) == :ok
  end
  
  test "counter example" do
    Quantum.execute("5 * * * *", fn -> IO.puts("FAIL") end, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1})
  end
  
  test "parse" do
    assert Quantum.parse("0/20", 0, 59) == [0]
    assert Quantum.parse("15-45/5", 0, 59) == [15, 20, 25, 30, 35, 40, 45]
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
