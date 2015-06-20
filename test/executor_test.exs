defmodule Quantum.ExecutorTest do
  use ExUnit.Case

  import Quantum.Executor

  defp ok, do: :ok

  test "check minutely" do
    assert execute({"* * * * *", &ok/0}, %{}) == :ok
  end

  test "check hourly" do
    assert execute({"0 * * * *", &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert execute({"0 * * * *", &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
    assert execute({"@hourly",   &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert execute({"@hourly",   &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
  end

  test "check daily" do
    assert execute({"0 0 * * *", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"0 0 * * *", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
    assert execute({"@daily",    &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"@daily",    &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
    assert execute({"@midnight", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"@midnight", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
  end

  test "check weekly" do
    assert execute({"0 0 * * 0", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 * * 0", &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 0}) == false
    assert execute({"@weekly",   &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@weekly",   &ok/0}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 0}) == false
  end

  test "check monthly" do
    assert execute({"0 0 1 * *", &ok/0}, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 1 * *", &ok/0}, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@monthly",  &ok/0}, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@monthly",  &ok/0}, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "check yearly" do
    assert execute({"0 0 1 1 *", &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 1 1 *", &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@annually", &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@annually", &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@yearly",   &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@yearly",   &ok/0}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "parse */5" do
    assert execute({"*/5 * * * *", &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
  end

  test "parse 5" do
    assert execute({"5 * * * *",  &ok/0}, %{d: {2015, 12, 31}, h: 12, m: 5, w: 1}) == :ok
  end
  
  test "counter example" do
    execute({"5 * * * *", &flunk/0}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1})
  end

end
