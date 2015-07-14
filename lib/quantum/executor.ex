defmodule Quantum.Executor do

  @moduledoc false

  import Quantum.Matcher

  def execute({"@reboot",   fun}, %{r: 1}), do: execute_fun(fun)
  def execute(_,                  %{r: 1}), do: false
  def execute({"* * * * *", fun}, _), do: execute_fun(fun)
  def execute({"@hourly",   fun}, %{m: 0}), do: execute_fun(fun)
  def execute({"0 * * * *", fun}, %{m: 0}), do: execute_fun(fun)
  def execute({"@daily",    fun}, %{m: 0, h: 0}), do: execute_fun(fun)
  def execute({"@midnight", fun}, %{m: 0, h: 0}), do: execute_fun(fun)
  def execute({"0 0 * * *", fun}, %{m: 0, h: 0}), do: execute_fun(fun)
  def execute({"@weekly",   fun}, %{m: 0, h: 0, w: 0}), do: execute_fun(fun)
  def execute({"0 0 * * 0", fun}, %{m: 0, h: 0, w: 0}), do: execute_fun(fun)
  def execute({"@monthly",  fun}, %{m: 0, h: 0, d: {_, _, 1}}), do: execute_fun(fun)
  def execute({"0 0 1 * *", fun}, %{m: 0, h: 0, d: {_, _, 1}}), do: execute_fun(fun)
  def execute({"@annually", fun}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun)
  def execute({"@yearly",   fun}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun)
  def execute({"0 0 1 1 *", fun}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun)
  def execute({"@hourly",   _}, _), do: false
  def execute({"@daily",    _}, _), do: false
  def execute({"@midnight", _}, _), do: false
  def execute({"@weekly",   _}, _), do: false
  def execute({"@annually", _}, _), do: false
  def execute({"@yearly",   _}, _), do: false
  def execute({"@monthly",  _}, _), do: false
  def execute({e, fun}, state) do
    [m, h, d, n, w] = e |> String.split(" ")
    {_, cur_mon, cur_day} = state.d
    cond do
      !match(m, state.m, 0, 59) -> false
      !match(h, state.h, 0, 24) -> false
      !match(d, cur_day, 1, 31) -> false
      !match(n, cur_mon, 1, 12) -> false
      !match(w, state.w, 0,  6) -> false
      true                      -> execute_fun(fun)
    end
  end

  defp execute_fun({module, method}) do
    :erlang.apply(String.to_atom("Elixir.#{module}"), method, [])
  end

  defp execute_fun(fun), do: fun.()
end
