defmodule Lux.Lenses.Twitter.GetUser do
  @moduledoc """
  Lens for retrieving a User by ID.

  ## Examples
      Lux.Lenses.Twitter.GetUser.focus(%{id: "2244994945"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User",
    description: "Retrieve a user object by numeric ID",
    url: "https://api.twitter.com/2/users/:id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the user"},
        "user.fields": %{type: :string, description: "Comma-separated list of fields"}
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       id: data["id"],
       name: data["name"],
       username: data["username"],
       created_at: data["created_at"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
