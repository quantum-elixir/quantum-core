defmodule Quantum.Application do
  use Application

  def start(_, _) do
    Quantum.start_link
  end

end
