defmodule Lux.MixProject do
  use Mix.Project

  def project do
    [
      app: :lux,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
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
      "test.integration": "test --include integration",
      # run all tests
      "test.suite": "test --include unit --include integration"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:venomous, "~> 0.7.5"},
      {:crontab, "~> 1.1"},
      {:ex_json_schema, "~> 0.10.2"},
      {:nodejs, "~> 2.0"},
      # test and dev dependencies
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
        "test.unit": :test,
        "test.suite": :test
      ]
    ]
  end
end
