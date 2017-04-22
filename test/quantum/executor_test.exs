defmodule Quantum.ExecutorTest do
  use ExUnit.Case

  @default_date %{date: ~N[2015-12-31 12:00:00]}

  import Quantum.Executor
  import Crontab.CronExpression

  def ok, do: :ok

  test "check minutely" do
    assert execute({~e[* * * * *], &ok/0, :utc}, @default_date) === true
  end

  test "check hourly" do
    assert execute({~e[0 * * * *], &ok/0, :utc}, %{date: ~N[2015-12-31 12:00:00]}) === true
    assert execute({~e[0 * * * *], &ok/0, :utc}, %{date: ~N[2015-12-31 12:01:00]}) === false
    assert execute({~e[@hourly],   &ok/0, :utc}, %{date: ~N[2015-12-31 12:00:00]}) === true
    assert execute({~e[@hourly],   &ok/0, :utc}, %{date: ~N[2015-12-31 12:01:00]}) === false
  end

  test "check daily" do
    assert execute({~e[0 0 * * *], &ok/0, :utc}, %{date: ~N[2015-12-31 00:00:00]}) === true
    assert execute({~e[0 0 * * *], &ok/0, :utc}, %{date: ~N[2015-12-31 00:01:00]}) === false
    assert execute({~e[@daily],    &ok/0, :utc}, %{date: ~N[2015-12-31 00:00:00]}) === true
    assert execute({~e[@daily],    &ok/0, :utc}, %{date: ~N[2015-12-31 00:01:00]}) === false
    assert execute({~e[@midnight], &ok/0, :utc}, %{date: ~N[2015-12-31 00:00:00]}) === true
    assert execute({~e[@midnight], &ok/0, :utc}, %{date: ~N[2015-12-31 00:01:00]}) === false
  end

  test "check weekly" do
    assert execute({~e[0 0 * * 0], &ok/0, :utc}, %{date: ~N[2015-12-27 00:00:00]}) === true
    assert execute({~e[0 0 * * 0], &ok/0, :utc}, %{date: ~N[2015-12-27 00:01:00]}) === false
    assert execute({~e[@weekly],   &ok/0, :utc}, %{date: ~N[2015-12-27 00:00:00]}) === true
    assert execute({~e[@weekly],   &ok/0, :utc}, %{date: ~N[2015-12-27 00:01:00]}) === false
  end

  test "check monthly" do
    assert execute({~e[0 0 1 * *], &ok/0, :utc}, %{date: ~N[2015-12-01 00:00:00]}) === true
    assert execute({~e[0 0 1 * *], &ok/0, :utc}, %{date: ~N[2015-12-01 00:01:00]}) === false
    assert execute({~e[@monthly],  &ok/0, :utc}, %{date: ~N[2015-12-01 00:00:00]}) === true
    assert execute({~e[@monthly],  &ok/0, :utc}, %{date: ~N[2015-12-01 00:01:00]}) === false
  end

  test "check yearly" do
    assert execute({~e[0 0 1 1 *], &ok/0, :utc}, %{date: ~N[2016-01-01 00:00:00]}) === true
    assert execute({~e[0 0 1 1 *], &ok/0, :utc}, %{date: ~N[2016-01-01 00:01:00]}) === false
    assert execute({~e[@annually], &ok/0, :utc}, %{date: ~N[2016-01-01 00:00:00]}) === true
    assert execute({~e[@annually], &ok/0, :utc}, %{date: ~N[2016-01-01 00:01:00]}) === false
    assert execute({~e[@yearly],   &ok/0, :utc}, %{date: ~N[2016-01-01 00:00:00]}) === true
    assert execute({~e[@yearly],   &ok/0, :utc}, %{date: ~N[2016-01-01 00:01:00]}) === false
  end

  test "parse */5" do
    assert execute({~e[*/5 * * * *], &ok/0, :utc}, %{date: ~N[2015-12-31 12:00:00]}) === true
  end

  test "parse 5" do
    assert execute({~e[5 * * * *],  &ok/0, :utc}, %{date: ~N[2015-12-31 12:05:00]}) === true
  end

  test "counter example" do
    execute({~e[5 * * * *], &flunk/0, :utc}, %{date: ~N[2015-12-31 12:00:00]})
  end

  test "function as tuple" do
    assert execute({~e[* * * * *], {__MODULE__, :ok, []}, :utc}, @default_date) === true
  end

  test "readable schedule" do
    assert execute({~e[@weekly], {__MODULE__, :ok, []}, :utc}, %{date: ~N[2015-12-27 00:00:00]}) === true
  end

  test "function with args" do
    assert execute({~e[* * * * *], &ok/0, :utc}, @default_date) === true
  end

  test "reboot" do
    assert execute({~e[@reboot], &ok/0, :utc}, %{reboot: true}) === true
    assert execute({~e[@reboot], &ok/0, :utc}, %{reboot: false}) === false
  end

  test "Raise if trying to use 'local' timezone" do
    assert assert_raise(RuntimeError, fn -> execute({~e[@daily], &ok/0, :local}, %{date: ~N[2015-12-31 00:00:00]}) end)
  end

  test "accepts custom timezones" do
    assert execute({~e[@daily], &ok/0, "Etc/GMT+1"}, %{date: ~N[2015-12-31 01:00:00]}) === true
  end

  test "accepts custom timezones(America/Chicago)" do
    assert execute({~e[@daily], &ok/0, "America/Chicago"}, %{date: ~N[2015-12-31 06:00:00]}) === true
  end
end
