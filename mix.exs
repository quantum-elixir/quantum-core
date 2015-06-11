defmodule Quantum.Mixfile do
  use Mix.Project

  def project do
    [
      app: :quantum,
      version: "1.2.0",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: [{:excoveralls, "~> 0.3", only: [:dev, :test]}],
      test_coverage: [tool: ExCoveralls],
      description: "Cron-like job scheduler for Elixir applications.",
      package: package
    ]
  end

  def application do
    [applications: [], mod: {Quantum.Application, []}]
  end

  defp package do
    %{
      contributors: ["Constantin Rack"],
      licenses: ["Apache License 2.0"],
      links: %{"Github" => "https://github.com/c-rack/quantum-elixir"}
    }
  end

end
