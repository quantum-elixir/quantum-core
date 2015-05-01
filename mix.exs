defmodule Quantum.Mixfile do
  use Mix.Project

  def project do
    [
      app: :quantum,
      version: "1.0.3",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: [],
      description: "Cron-like job scheduler for Elixir applications.",
      package: package
    ]
  end

  def application,        do: application(Mix.env)
  def application(:test), do: [applications: []]
  def application(_),     do: [applications: [], mod: {Quantum.Application, []}]

  defp package do
    %{
      contributors: ["Constantin Rack"],
      licenses: ["Apache License 2.0"],
      links: %{"Github" => "https://github.com/c-rack/quantum-elixir"}
    }
  end

end
