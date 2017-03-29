defmodule Quantum.ExecutorTest do
  use ExUnit.Case

  @default_timezone Application.get_env(:quantum, :timezone, :utc)
  @default_date %{d: {2015, 12, 31}, h: 12, m: 0, s: 0, w: 1}

  import Quantum.Executor
  import Crontab.CronExpression

  def ok,     do: :ok
  def ret(v), do: v

  setup context do
    if timezone = context[:timezone] do
      on_exit(context, fn ->
        Application.delete_env(:quantum, :timezone)
      end)

      case timezone do
        "local" ->
          Application.put_env(:quantum, :timezone, :local)
        "CET" ->
          Application.put_env(:quantum, :timezone, "Etc/GMT+1")
        "America/Chicago" ->
          Application.put_env(:quantum, :timezone, "America/Chicago")
      end
    end

    :ok
  end

  test "check minutely" do
    assert execute({~e[* * * * *], &ok/0, @default_timezone}, @default_date) == :ok
  end

  test "check hourly" do
    assert execute({~e[0 * * * *], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, s: 0, w: 1}) == :ok
    assert execute({~e[0 * * * *], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 1, s: 0, w: 1}) == false
    assert execute({~e[@hourly],   &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, s: 0, w: 1}) == :ok
    assert execute({~e[@hourly],   &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 1, s: 0, w: 1}) == false
  end

  test "check daily" do
    assert execute({~e[0 0 * * *], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) == :ok
    assert execute({~e[0 0 * * *], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, s: 0, w: 1}) == false
    assert execute({~e[@daily],    &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) == :ok
    assert execute({~e[@daily],    &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, s: 0, w: 1}) == false
    assert execute({~e[@midnight], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) == :ok
    assert execute({~e[@midnight], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 0, m: 1, s: 0, w: 1}) == false
  end

  test "check weekly" do
    assert execute({~e[0 0 * * 0], &ok/0, @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[0 0 * * 0], &ok/0, @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 1, s: 0, w: 0}) == false
    assert execute({~e[@weekly],   &ok/0, @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[@weekly],   &ok/0, @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 1, s: 0, w: 0}) == false
  end

  test "check monthly" do
    assert execute({~e[0 0 1 * *], &ok/0, @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[0 0 1 * *], &ok/0, @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 1, s: 0, w: 0}) == false
    assert execute({~e[@monthly],  &ok/0, @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[@monthly],  &ok/0, @default_timezone}, %{d: {2015, 12, 1}, h: 0, m: 1, s: 0, w: 0}) == false
  end

  test "check yearly" do
    assert execute({~e[0 0 1 1 *], &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[0 0 1 1 *], &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, s: 0, w: 0}) == false
    assert execute({~e[@annually], &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[@annually], &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, s: 0, w: 0}) == false
    assert execute({~e[@yearly],   &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 0, s: 0, w: 0}) == :ok
    assert execute({~e[@yearly],   &ok/0, @default_timezone}, %{d: {2016, 1, 1}, h: 0, m: 1, s: 0, w: 0}) == false
  end

  test "parse */5" do
    assert execute({~e[*/5 * * * *], &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, s: 0, w: 1}) == :ok
  end

  test "parse 5" do
    assert execute({~e[5 * * * *],  &ok/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 5, s: 0, w: 1}) == :ok
  end

  test "counter example" do
    execute({~e[5 * * * *], &flunk/0, @default_timezone}, %{d: {2015, 12, 31}, h: 12, m: 0, s: 0, w: 1})
  end

  test "function as tuple" do
    assert execute({~e[* * * * *], {__MODULE__, :ok, []}, @default_timezone}, @default_date) == :ok
  end

  test "readable schedule" do
    assert execute({~e[@weekly], {__MODULE__, :ok, []}, @default_timezone}, %{d: {2015, 12, 27}, h: 0, m: 0, s: 0, w: 0}) == :ok
  end

  test "function with args" do
    assert execute({~e[* * * * *], &ok/0, @default_timezone}, @default_date) == :ok
  end

  test "reboot" do
    assert execute({~e[@reboot], &ok/0, @default_timezone}, %{r: 1}) == :ok
    assert execute({~e[@reboot], &ok/0, @default_timezone}, %{r: 0}) == false
  end

  @tag timezone: "local"
  test "Raise if trying to use 'local' timezone" do
    assert assert_raise(RuntimeError, fn -> execute({~e[@daily], &ok/0, :local}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) end)
  end

  @tag timezone: "CET"
  test "accepts custom timezones" do
    assert execute({~e[@daily], &ok/0, "Etc/GMT+1"}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) == :ok
  end

  @tag timezone: "America/Chicago"
  test "accepts custom timezones(America/Chicago)" do
    assert execute({~e[@daily], &ok/0, "America/Chicago"}, %{d: {2015, 12, 31}, h: 0, m: 0, s: 0, w: 1}) == :ok
  end
end
