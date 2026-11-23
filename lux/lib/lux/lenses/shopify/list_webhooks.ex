defmodule Lux.Lenses.Shopify.ListWebhooks do
  @moduledoc """
  A lens for listing webhook subscriptions from the Shopify Admin API.

  ## Examples

      iex> ListWebhooks.focus(%{})
      {:ok, [%{"id" => 123, "topic" => "orders/create"}]}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "List Shopify Webhooks",
    description: "Lists webhook subscriptions from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/webhooks.json",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(%{"webhooks" => webhooks}), do: {:ok, webhooks}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
end