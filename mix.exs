defmodule Quantum.Mixfile do
  @moduledoc false

  use Mix.Project

  @source_url "https://github.com/quantum-elixir/quantum-core"
  @version "3.5.0"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: "Cron-like job scheduler for Elixir.",
      docs: docs(),
      elixir: "~> 1.12",
      name: "Quantum",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
      build_embedded: (System.get_env("BUILD_EMBEDDED") || "false") in ["1", "true"],
      dialyzer:
        [list_unused_filters: true, ignore_warnings: "dialyzer.ignore-warnings"] ++
          if (System.get_env("DIALYZER_PLT_PRIV") || "false") in ["1", "true"] do
            [plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
          else
            []
          end,
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "coveralls.xml": :test
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
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
      exclude_patterns: [~r[priv/plts]],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      }
    }
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      logo: "assets/quantum-elixir-logo.svg",
      extras: [
        "CHANGELOG.md",
        "README.md",
        "pages/supervision-tree.md",
        "pages/configuration.md",
        "pages/runtime-configuration.md",
        "pages/crontab-format.md",
        "pages/run-strategies.md"
      ],
      groups_for_modules: [
        "Run Strategy": [
          Quantum.RunStrategy,
          Quantum.RunStrategy.All,
          Quantum.RunStrategy.Local,
          Quantum.RunStrategy.NodeList,
          Quantum.RunStrategy.Random
        ],
        Storage: [
          Quantum.Storage,
          Quantum.Storage.Noop
        ]
      ]
    ]
  end

  defp deps do
    [
      {:crontab, "~> 1.1"},
      {:gen_stage, "~> 0.14 or ~> 1.0"},
      {:telemetry, "~> 0.4.3 or ~> 1.0"},
      {:tzdata, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.5", only: [:test], runtime: false},
      {:dialyxir, "~> 1.0-rc", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:telemetry_registry, "~> 0.2"}
    ]
  end
end
