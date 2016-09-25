defmodule Quantum.ExecutorTest do
  use ExUnit.Case

  @default_timezone Application.get_env(:quantum, :timezone, :utc)

  import Quantum.Executor

  def ok,     do: :ok
  def ret(v), do: v

  setup context do
    if timezone = context[:timezone] do
      on_exit(context, fn ->
        Application.delete_env(:quantum, :timezone)
        Application.delete_env(:timex, :local_timezone)
      end)

      case timezone do
        "local" ->
          Application.put_env(:quantum, :timezone, :local)
          Application.put_env(:timex, :local_timezone, "Etc/GMT+1")
        "CET" ->
          Application.put_env(:quantum, :timezone, "Etc/GMT+1")
        "America/Chicago" ->
          Application.put_env(:quantum, :timezone, "America/Chicago")
      end
    end

    :ok
  end

  test "check minutely" do
    assert execute({"* * * * *", &ok/0, [], @default_timezone}, %{}) == :ok
  end

  test "check hourly" do
    assert execute({"0 * * * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert execute({"0 * * * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
    assert execute({"@hourly",   &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
    assert execute({"@hourly",   &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 1, w: 1}) == false
  end

  test "check daily" do
    assert execute({"0 0 * * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"0 0 * * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
    assert execute({"@daily",    &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"@daily",    &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
    assert execute({"@midnight", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
    assert execute({"@midnight", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, w: 1}) == false
  end

  test "check weekly" do
    assert execute({"0 0 * * 0", &ok/0, [], @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 * * 0", &ok/0, [], @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 1, w: 0}) == false
    assert execute({"@weekly",   &ok/0, [], @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@weekly",   &ok/0, [], @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 1, w: 0}) == false
  end

  test "check monthly" do
    assert execute({"0 0 1 * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 1 * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@monthly",  &ok/0, [], @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@monthly",  &ok/0, [], @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "check yearly" do
    assert execute({"0 0 1 1 *", &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"0 0 1 1 *", &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@annually", &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@annually", &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
    assert execute({"@yearly",   &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, w: 0}) == :ok
    assert execute({"@yearly",   &ok/0, [], @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, w: 0}) == false
  end

  test "parse */5" do
    assert execute({"*/5 * * * *", &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1}) == :ok
  end

  test "parse 5" do
    assert execute({"5 * * * *",  &ok/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 5, w: 1}) == :ok
  end

  test "counter example" do
    execute({"5 * * * *", &flunk/0, [], @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, w: 1})
  end

  test "function as tuple" do
    assert execute({"* * * * *", {__MODULE__, :ok}, [], @default_timezone}, %{}) == :ok
    assert execute({"* * * * *", {"Quantum.ExecutorTest", "ok"}, [], @default_timezone}, %{}) == :ok
  end

  test "readable schedule" do
    assert execute({"@weekly", {__MODULE__, :ok}, [], @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, w: 0}) == :ok
  end

  test "function with args" do
    assert execute({"* * * * *", &ret/1, [:passed], @default_timezone}, %{}) == :passed
  end

  test "reboot" do
    assert execute({"@reboot", &ok/0, [], @default_timezone}, %{r: 1}) == :ok
    assert execute({"@reboot", &ok/0, [], @default_timezone}, %{r: 0}) == false
  end

  @tag timezone: "local"
  test "accepts local timezone" do
    assert execute({"@daily", &ok/0, [], :local}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
  end

  @tag timezone: "CET"
  test "accepts custom timezones" do
    assert execute({"@daily", &ok/0, [], "Etc/GMT+1"}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
  end

  @tag timezone: "America/Chicago"
  test "accepts custom timezones(America/Chicago)" do
    assert execute({"@daily", &ok/0, [], "America/Chicago"}, %{d: {2015, 12, 31}, h: 0, m: 0, w: 1}) == :ok
  end
end
