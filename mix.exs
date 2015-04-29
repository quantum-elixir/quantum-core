defmodule Quantum.Mixfile do
  use Mix.Project

  def project do
    [
      app: :quantum,
      version: "1.0.2",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      description: "Cron-like job scheduler for Elixir applications.",
      package: package
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    application(Mix.env)
  end
  def application(:test) do
    [applications: []]
  end
  def application(_) do
    [applications: [], mod: {Quantum.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    []
  end

  defp package do
    %{
      contributors: ["Constantin Rack"],
      licenses: ["Apache License 2.0"],
      links: %{"Github" => "https://github.com/c-rack/quantum-elixir"}
    }
  end

end
