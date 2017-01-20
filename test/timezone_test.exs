defmodule Quantum.TimezoneTest do
  use ExUnit.Case

  import Quantum.Executor
  import Crontab.CronExpression

  def ok,     do: :ok
  def ret(v), do: v

  test "check timezones" do
    # We choose timezones with no daylight savings time or other weird things going on, so that these tests can pass at all times
    assert execute({~e[0 21 15 * *], &ok/0, [], "Etc/GMT+2"}, %{d: {2015, 12, 15}, h: 23, m: 0, w: 1}) == :ok
    assert execute({~e[0 21 15 * *], &ok/0, [], "Etc/GMT+3"}, %{d: {2015, 12, 16}, h: 0, m: 0, w: 1}) == :ok
    assert execute({~e[0 21 15 * *], &ok/0, [], "Etc/GMT+3"}, %{d: {2015, 12, 15}, h: 0, m: 0, w: 1}) == false
  end

  test "check timezone with weekly" do
    assert execute({~e[@weekly], &ok/0, [], "Etc/GMT-3"}, %{d: {2016, 3, 5}, h: 21, m: 0, w: 1}) == :ok
    assert execute({~e[@weekly], &ok/0, [], "Etc/GMT-3"}, %{d: {2016, 3, 6}, h: 0, m: 0, w: 1}) == false
  end

  test "check timezone with monthly" do
    assert execute({~e[@monthly], &ok/0, [], "Etc/GMT-3"}, %{d: {2016, 2, 29}, h: 21, m: 0, w: 1}) == :ok
    assert execute({~e[@monthly], &ok/0, [], "Etc/GMT-3"}, %{d: {2016, 3, 1}, h: 0, m: 0, w: 1}) == false
  end

end
