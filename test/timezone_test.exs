defmodule Quantum.TimezoneTest do
  use ExUnit.Case

  import Quantum.Executor
  import Crontab.CronExpression

  def ok,     do: :ok
  def ret(v), do: v

  test "check timezones" do
    # We choose timezones with no daylight savings time or other weird things going on, so that these tests can pass at all times
    assert execute({~e[0 21 15 * *], &ok/0, "Etc/GMT+2"}, %{date: ~N[2015-12-15 23:00:00]}) === true
    assert execute({~e[0 21 15 * *], &ok/0, "Etc/GMT+3"}, %{date: ~N[2015-12-16 00:00:00]}) === true
    assert execute({~e[0 21 15 * *], &ok/0, "Etc/GMT+3"}, %{date: ~N[2015-12-15 00:00:00]}) === false
  end

  test "check timezone with weekly" do
    assert execute({~e[@weekly], &ok/0, "Etc/GMT-3"}, %{date: ~N[2016-03-05 21:00:00]}) === true
    assert execute({~e[@weekly], &ok/0, "Etc/GMT-3"}, %{date: ~N[2016-03-06 00:00:00]}) === false
  end

  test "check timezone with monthly" do
    assert execute({~e[@monthly], &ok/0, "Etc/GMT-3"}, %{date: ~N[2016-02-29 21:00:00]}) === true
    assert execute({~e[@monthly], &ok/0, "Etc/GMT-3"}, %{date: ~N[2016-03-01 00:00:00]}) === false
  end
end
