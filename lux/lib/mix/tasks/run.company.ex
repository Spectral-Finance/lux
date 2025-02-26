defmodule Mix.Tasks.Run.Company do
  @moduledoc """
  Runs a Lux company.

  ## Usage

      mix run.company MyApp.Companies.ContentTeam

  This will start the company and keep it running until interrupted.
  """

  use Mix.Task

  @impl Mix.Task
  def run([company_module]) do
    # Start the application
    Mix.Task.run("app.start")

    # Convert the string to a module atom
    module =
      company_module
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
      |> Enum.reduce(&Module.concat/2)

    # Start the company
    case Lux.Company.start_link(module) do
      {:ok, pid} ->
        IO.puts("Started company #{company_module} (#{inspect(pid)})")
        # Keep the process running
        Process.sleep(:infinity)

      {:error, reason} ->
        Mix.raise("Failed to start company: #{inspect(reason)}")
    end
  end

  def run(_) do
    Mix.raise("""
    Invalid arguments.

    Usage:
        mix run.company MyApp.Companies.ContentTeam
    """)
  end
end
