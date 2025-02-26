defmodule LuxCliMixProject do
  use Mix.Project

  def project do
    [
      app: :lux_cli,
      version: "0.5.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: escript(),
      # Package
      description: "Command-line interface for the Lux framework",
      package: package(),
      # Docs
      name: "Lux CLI",
      source_url: "https://github.com/Spectral-Finance/lux",
      homepage_url: "https://lux.spectrallbas.xyz",
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependency
      {:lux_core, path: "../core"},
      # Optional web dependency
      {:lux_web, path: "../web", optional: true},

      # CLI dependencies
      {:optimus, "~> 0.2"},

      # Development tools
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: :dev, runtime: false},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  def escript do
    [
      main_module: Lux.CLI,
      name: "lux",
      app: nil,
      path: "bin/lux"
    ]
  end

  def package do
    [
      name: "lux_cli",
      description:
        "Lux CLI provides a command-line interface for the Lux framework, allowing users to create, manage, and monitor agent workflows from the terminal.",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Spectral-Finance/lux",
        "Changelog" => "https://github.com/Spectral-Finance/lux/blob/main/CHANGELOG.md"
      },
      files: ~w(lib bin .formatter.exs mix.exs README.md)
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
