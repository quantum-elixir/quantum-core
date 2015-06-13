defmodule Quantum.Mixfile do
  use Mix.Project

  @version "1.2.1"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env == :prod,
      deps: [
        {:earmark, "~> 0.1", only: [:dev, :docs]},
        {:excoveralls, "~> 0.3", only: [:dev, :test]},
        {:ex_doc, "~> 0.7", only:  [:dev, :docs]}
      ],
      description: "Cron-like job scheduler for Elixir applications.",
      docs: [
        main: "README",
        readme: "README.md",
        source_ref: "v#{@version}",
        source_url: "https://github.com/c-rack/quantum-elixir"
      ],
      elixir: "~> 1.0",
      name: "Quantum",
      package: package,
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
    ]
  end

  def application do
    [applications: [], mod: {Quantum.Application, []}]
  end

  defp package do
    %{
      contributors: ["Constantin Rack"],
      licenses: ["Apache License 2.0"],
      links: %{
        "Docs" => "https://hexdocs.pm/quantum",
        "Github" => "https://github.com/c-rack/quantum-elixir"
      }
    }
  end

end
