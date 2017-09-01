defmodule Quantum.Mixfile do
  @moduledoc false

  use Mix.Project

  @version "2.0.4"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      description: "Cron-like job scheduler for Elixir.",
      docs: docs(),
      elixir: ">= 1.4.0",
      name: "Quantum",
      package: package(),
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"]
    ]
  end

  def application do
    [mod: {Quantum.Application, []},
     extra_applications: [:logger]]
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
        "Kai Faber",
        "Jonatan Männchen"
      ],
      licenses: ["Apache License 2.0"],
      links: %{
        "Changelog" => "https://github.com/c-rack/quantum-elixir/blob/master/CHANGELOG.md",
        "GitHub" => "https://github.com/c-rack/quantum-elixir"
      }
    }
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/c-rack/quantum-elixir",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "MIGRATE-V2.md",
        "pages/supervision-tree.md",
        "pages/configuration.md",
        "pages/runtime.md",
        "pages/crontab-format.md",
        "pages/run-strategies.md",
        "pages/date-library.md"
      ]
    ]
  end

  defp deps do
    [
      {:timex,       "~> 3.1.13", optional: true},
      {:calendar,    "~> 0.17", optional: true},
      {:crontab,     "~> 1.1"},
      {:earmark,     "~> 1.0",  only: [:dev, :docs], runtime: false},
      {:ex_doc,      "~> 0.13", only: [:dev, :docs], runtime: false},
      {:excoveralls, "~> 0.5",  only: [:dev, :test], runtime: false},
      {:inch_ex,     "~> 0.5",  only: [:dev, :docs], runtime: false},
      {:dialyxir,    "~> 0.5",  only: [:dev, :test], runtime: false},
      {:credo,       "~> 0.7",  only: [:dev, :test], runtime: false}
    ]
  end
end
