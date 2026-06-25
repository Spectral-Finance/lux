defmodule Lux.Prisms.Discord.Voice.ListRegions do
  @moduledoc """
  A prism for listing Discord voice regions.

  Retrieves available voice regions from the Discord API.

  ## Examples

      iex> ListRegions.handler(%{}, %{name: "Agent"})
      {:ok, %{regions: [%{"id" => "us-west", "name" => "US West", ...}], count: 14}}

  """

  use Lux.Prism,
    name: "List Discord Voice Regions",
    description: "Lists available Discord voice regions",
    input_schema: %{
      type: :object,
      properties: %{}
    },
    output_schema: %{
      type: :object,
      properties: %{
        regions: %{type: :array, description: "Voice region objects"},
        count: %{type: :integer, description: "Number of regions"}
      },
      required: ["regions"]
    }

  alias Lux.Integrations.Discord.Voice
  require Logger

  def handler(_params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} listing Discord voice regions")

    case Voice.list_regions() do
      {:ok, regions} ->
        Logger.info("Fetched #{length(regions)} voice regions")
        {:ok, %{regions: regions, count: length(regions)}}

      {:error, error} ->
        Logger.error("Failed to fetch voice regions: #{inspect(error)}")
        {:error, error}
    end
  end
end
