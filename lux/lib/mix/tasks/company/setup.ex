defmodule Mix.Tasks.Company.Setup do
  @moduledoc """
  Sets up a new company with job openings using configuration from a YAML file.

  ## Usage

      mix company.setup [path/to/config.yaml]

  If no config file is specified, it will use the default at `config/company_setup.yaml`.

  ## Example

      mix company.setup
      mix company.setup path/to/my/config.yaml
  """

  use Mix.Task

  require Logger

  @default_config "config/company_setup.yaml"
  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    config_path = List.first(args) || @default_config

    if !File.exists?(config_path) do
      Mix.raise("Configuration file not found: #{config_path}")
    end

    Logger.info("Reading configuration from #{config_path}")

    case YamlElixir.read_from_file(config_path) do
      {:ok, config} ->
        run_setup_beam(config)

      {:error, error} ->
        Mix.raise("Failed to parse YAML configuration: #{inspect(error)}")
    end
  end

  defp run_setup_beam(config) do
    Logger.info("Setting up company: #{config["company"]["name"]}")

    # Transform the YAML input into the format expected by the beam
    beam_input = %{
      company: %{
        name: config["company"]["name"],
        agent_token: config["company"]["agent_token"]
      },
      jobs:
        Enum.map(config["jobs"], fn job ->
          %{name: job["name"]}
        end)
    }

    case Lux.Beams.AgenticCompany.SetupCompanyBeam.run(beam_input) do
      {:ok, result, execution_log} ->
        Logger.info("Company setup successful!")
        Logger.info("Company address: #{result.company_address}")
        Logger.info("Created jobs:")

        for job <- result.jobs do
          Logger.info("  - #{job.name} (ID: #{job.job_id})")
        end

        {:ok, result, execution_log}

      {:error, error, execution_log} ->
        Mix.raise("""
        Failed to set up company:
        Error: #{inspect(error)}
        Execution Log: #{inspect(execution_log)}
        """)
    end
  end
end
