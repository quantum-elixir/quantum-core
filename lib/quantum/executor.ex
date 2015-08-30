defmodule Quantum.Executor do

  @moduledoc false

  import Quantum.Matcher

  def execute({"@reboot",   fun, args}, %{r: 1}), do: execute_fun(fun, args)
  def execute(_,                  %{r: 1}), do: false
  def execute({"@reboot",   _},   %{r: 0}), do: false
  def execute({"* * * * *", fun, args}, _), do: execute_fun(fun, args)
  def execute({"@hourly",   fun, args}, %{m: 0}), do: execute_fun(fun, args)
  def execute({"0 * * * *", fun, args}, %{m: 0}), do: execute_fun(fun, args)
  def execute({"@daily",    fun, args}, %{m: 0, h: 0}), do: execute_fun(fun, args)
  def execute({"@midnight", fun, args}, %{m: 0, h: 0}), do: execute_fun(fun, args)
  def execute({"0 0 * * *", fun, args}, %{m: 0, h: 0}), do: execute_fun(fun, args)
  def execute({"@weekly",   fun, args}, %{m: 0, h: 0, w: 0}), do: execute_fun(fun, args)
  def execute({"0 0 * * 0", fun, args}, %{m: 0, h: 0, w: 0}), do: execute_fun(fun, args)
  def execute({"@monthly",  fun, args}, %{m: 0, h: 0, d: {_, _, 1}}), do: execute_fun(fun, args)
  def execute({"0 0 1 * *", fun, args}, %{m: 0, h: 0, d: {_, _, 1}}), do: execute_fun(fun, args)
  def execute({"@annually", fun, args}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun, args)
  def execute({"@yearly",   fun, args}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun, args)
  def execute({"0 0 1 1 *", fun, args}, %{m: 0, h: 0, d: {_, 1, 1}}), do: execute_fun(fun, args)
  def execute({"@hourly",   _, _}, _), do: false
  def execute({"@daily",    _, _}, _), do: false
  def execute({"@midnight", _, _}, _), do: false
  def execute({"@weekly",   _, _}, _), do: false
  def execute({"@annually", _, _}, _), do: false
  def execute({"@yearly",   _, _}, _), do: false
  def execute({"@monthly",  _, _}, _), do: false
  def execute({e, fun, args}, state) do
    [m, h, d, n, w] = e |> String.split(" ")
    {_, cur_mon, cur_day} = state.d
    cond do
      !match(m, state.m, 0, 59) -> false
      !match(h, state.h, 0, 24) -> false
      !match(d, cur_day, 1, 31) -> false
      !match(n, cur_mon, 1, 12) -> false
      !match(w, state.w, 0,  6) -> false
      true                      -> execute_fun(fun, args)
    end
  end

  defp execute_fun({mod, fun}, args) do
    mod = cond do
      is_binary(mod) -> String.to_atom("Elixir.#{mod}")
      true -> mod
    end
    fun = cond do
      is_binary(fun) -> String.to_atom(fun)
      true -> fun
    end
    :erlang.apply(mod, fun, args)
  end

  defp execute_fun(fun, args), do: :erlang.apply(fun, args)

end
