defmodule Lux.Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :lux_core,
      version: "0.5.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      # Package
      description:
        "A framework for building and orchestrating LLM-powered agent workflows in Elixir",
      package: package(),
      # Docs
      name: "Lux Core",
      source_url: "https://github.com/Spectral-Finance/lux",
      homepage_url: "https://lux.spectrallbas.xyz",
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Lux.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: [:logger, :crypto, :wx, :observer, :runtime_tools]
  defp extra_applications(_), do: [:logger, :crypto]

  defp elixirc_paths(:test), do: ["lib", "test/"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "test.unit": "test --include unit",
      "test.integration": "test --include integration"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:req, "~> 0.5.0"},
      {:venomous, "~> 0.7.5"},
      {:crontab, "~> 1.1"},
      {:ex_json_schema, "~> 0.10.2"},
      {:nodejs, "~> 2.0"},
      {:ethers, "~> 0.6.4"},
      {:ex_secp256k1, "~> 0.7.4"},
      {:yaml_elixir, "~> 2.9"},
      # test and dev dependencies
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: :dev, runtime: false},
      {:dotenvy, "~> 0.8.0", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: [:test]},
      {:stream_data, "~> 1.0", only: [:test]},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.integration": :test,
        "test.unit": :test
      ]
    ]
  end

  def package do
    [
      name: "lux_core",
      description:
        "Lux Core is the foundation of the Lux framework for building and orchestrating LLM-powered agent workflows. It provides the core components for creating, managing, and coordinating AI agents.",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Spectral-Finance/lux",
        "Changelog" => "https://github.com/Spectral-Finance/lux/blob/main/CHANGELOG.md"
      },
      files:
        ~w(lib priv/python/lux/*.py priv/python/hyperliquid_utils/*.py priv/python/*.py priv/python/*.toml priv/node/*.json priv/node/*.mjs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ]
    ]
  end
end
