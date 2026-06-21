defmodule Lux.Lenses.Twitter.GetUserLens do
  @moduledoc """
  Lens for fetching the authenticated user's information from X (Twitter) API v2.
  """

  use Lux.Lens,
    name: "Twitter.GetUser",
    description: "Retrieves the authenticated user's information",
    url: "https://api.twitter.com/2/users/me",
    method: :get

  @impl true
  def after_focus(response) do
    case response do
      {:ok, %{"data" => user}} ->
        {:ok, user}
      other -> other
    end
  end
end
