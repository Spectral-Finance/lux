defmodule Lux.MixProject do
  use Mix.Project

  def project do
    [
      app: :lux,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Lux.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_applications(:dev), do: [:logger, :crypto, :wx, :observer, :runtime_tools]
  defp extra_applications(_), do: [:logger, :crypto]
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:venomous, "~> 0.7.5"},
      {:crontab, "~> 1.1"},
      {:dotenvy, "~> 0.8.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:telemetry, "~> 1.2"},
      # Test and dev dependencies
      {:dialyxir, "~> 1.4.5", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17", only: :test},
      {:mock, "~> 0.3.0", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end
end
