defmodule Quantum.Mixfile do
  @moduledoc false

  use Mix.Project

  @version "3.0.0-rc.3"

  def project do
    [
      app: :quantum,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: "Cron-like job scheduler for Elixir.",
      docs: docs(),
      elixir: "~> 1.8",
      name: "Quantum",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: @version,
      build_embedded: (System.get_env("BUILD_EMBEDDED") || "false") in ["1", "true"],
      dialyzer:
        [
          ignore_warnings: "dialyzer.ignore-warnings"
        ] ++
          if (System.get_env("DIALYZER_PLT_PRIV") || "false") in ["1", "true"] do
            [
              plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
            ]
          else
            []
          end
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
        "pages/supervision-tree.md",
        "pages/configuration.md",
        "pages/runtime.md",
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
      {:tzdata, "~> 1.0", only: [:dev, :test]},
      {:earmark, "~> 1.0", only: [:dev, :docs], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev, :docs], runtime: false},
      {:excoveralls, "~> 0.5", only: [:test], runtime: false},
      {:dialyxir, "~> 1.0-rc", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
