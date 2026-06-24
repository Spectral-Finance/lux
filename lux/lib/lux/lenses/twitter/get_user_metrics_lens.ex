defmodule Lux.Lenses.Twitter.GetUserMetricsLens do
  @moduledoc """
  Lens to fetch user metrics (followers, following, tweet count).
  """
  use Lux.Lens

  alias Lux.Lenses.Twitter.Base, as: TwitterBase

  @impl true
  def name, do: "Twitter Get User Metrics Lens"

  @impl true
  def description, do: "Fetches user metrics (follower count, following count, etc) for a given Twitter username."

  @impl true
  def schema do
    %{
      type: :object,
      properties: %{
        username: %{
          type: :string,
          description: "The Twitter username to fetch metrics for."
        }
      },
      required: ["username"]
    }
  end

  @impl true
  def focus(%{"username" => username}, _context) do
    client = TwitterBase.client()

    Req.get(client, url: "/users/by/username/#{username}", params: [
      "user.fields": "public_metrics"
    ])
    |> TwitterBase.process_response()
    |> case do
      {:ok, %{"data" => %{"public_metrics" => metrics}}} ->
        {:ok, metrics}
      {:ok, other} ->
        {:error, "Unexpected response format: #{inspect(other)}"}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
