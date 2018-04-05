defmodule Quantum.CaptureLogExtend do
  @moduledoc false

  import ExUnit.CaptureLog

  def capture_log_with_return(fun) do
    ref = make_ref()

    logs =
      capture_log(fn ->
        return = fun.()
        send(self(), {:return, ref, return})
      end)

    receive do
      {:return, ^ref, return} ->
        {return, logs}
    end
  end
end
