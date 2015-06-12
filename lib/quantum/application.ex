defmodule Quantum.Application do
  use Application

  @moduledoc false

  def start(_, _) do
    Quantum.start_link
  end

end
