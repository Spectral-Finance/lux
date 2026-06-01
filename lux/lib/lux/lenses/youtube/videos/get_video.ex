defmodule Lux.Lenses.YouTube.Videos.GetVideo do
  @moduledoc """
  Reads YouTube video metadata.
  """

  alias Lux.Integrations.YouTube.Client

  def view do
    Lux.Lens.new(
      name: "Get YouTube Video",
      module_name: inspect(__MODULE__),
      description: "Gets YouTube video snippet, status, content details, and statistics",
      schema: %{
        type: :object,
        properties: %{
          id: %{type: :string, description: "YouTube video id"},
          access_token: %{type: :string, description: "OAuth access token"}
        },
        required: ["id", "access_token"]
      }
    )
  end

  def focus(input, _opts \\ %{}) do
    params = %{
      "part" => "snippet,status,contentDetails,statistics",
      "id" => Client.get(input, :id)
    }

    input
    |> Map.new()
    |> Map.put("params", params)
    |> then(&Client.request(:get, "/videos", &1))
    |> case do
      {:ok, %{"items" => [video | _]}} -> {:ok, video}
      {:ok, %{"items" => []}} -> {:error, :video_not_found}
      other -> other
    end
  end
end
