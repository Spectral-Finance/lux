defmodule Lux.Lenses.Twitter.MentionsLens do
  @moduledoc """
  Lens for fetching recent mentions of the authenticated user from X (Twitter) API v2.
  """

  use Lux.Lens,
    name: "Twitter.Mentions",
    description: "Retrieves recent mentions of the authenticated user",
    url: "https://api.twitter.com/2/users/me/mentions",
    method: :get

  @impl true
  def after_focus(response) do
    case response do
      {:ok, %{"data" => tweets}} ->
        {:ok, Enum.map(tweets, fn t -> 
          %{
            id: t["id"],
            text: t["text"],
            author_id: t["author_id"]
          }
        end)}
      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, []}
      {:error, _} = error -> error
      other -> {:ok, other}
    end
  end
end
