defmodule Quantum.Mixfile do
  @moduledoc false

  use Mix.Project

  @version "2.3.0"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: "Cron-like job scheduler for Elixir.",
      docs: docs(),
      elixir: ">= 1.7.0",
      name: "Quantum",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings",
        plt_add_apps: [:timex, :calendar]
      ]
    ]
  end

  def application do
    [mod: {Quantum.Application, []}, extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
        "Changelog" => "https://github.com/quantum-elixir/quantum-core/blob/master/CHANGELOG.md",
        "GitHub" => "https://github.com/quantum-elixir/quantum-core"
      }
    }
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/quantum-elixir/quantum-core",
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
      {:timex, "~> 3.1", optional: true},
      {:calendar, "~> 0.17", optional: true},
      {:crontab, "~> 1.1"},
      {:gen_stage, "~> 0.12"},
      {:swarm, "~> 3.3"},
      {:earmark, "~> 1.0", only: [:dev, :docs], runtime: false},
      {:ex_doc, "~> 0.13", only: [:dev, :docs], runtime: false},
      {:excoveralls, "~> 0.5", only: [:dev, :test], runtime: false},
      {:inch_ex, "~> 1.0", only: [:dev, :docs], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 0.7", only: [:dev, :test], runtime: false}
    ]
  end
end
