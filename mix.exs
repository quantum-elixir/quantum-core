defmodule Quantum.Mixfile do
  use Mix.Project

  @version "1.9.0"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env == :prod,
      deps: [
        {:calendar,    "~> 0.16"},
        {:crontab,     "~> 1.0.0"},
        {:credo,       "~> 0.4",  only: [:dev, :test]},
        {:earmark,     "~> 1.0",  only: [:dev, :docs]},
        {:ex_doc,      "~> 0.13", only: [:dev, :docs]},
        {:excoveralls, "~> 0.5",  only: [:dev, :test]},
        {:inch_ex,     "~> 0.5",  only: [:dev, :docs]}
      ],
      description: "Cron-like job scheduler for Elixir.",
      docs: [
        main: "Quantum",
        source_ref: "v#{@version}",
        source_url: "https://github.com/c-rack/quantum-elixir"
      ],
      elixir: ">= 1.3.0",
      name: "Quantum",
      package: package(),
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
    ]
  end

  def application do
    [applications: [:calendar], mod: {Quantum.Application, []}]
  end

  defp package do
    %{
      maintainers: [
        "Constantin Rack",
        "Dan Swain",
        "Lenz Gschwendtner",
        "Lucas Charles",
        "Rodion Vshevtsov",
        "Stanislav Krasnoyarov",
        "Kai Faber"
      ],
      licenses: ["Apache License 2.0"],
      links: %{
        "Changelog" => "https://github.com/c-rack/quantum-elixir/blob/master/CHANGELOG.md",
        "GitHub" => "https://github.com/c-rack/quantum-elixir"
      }
    }
  end

end
