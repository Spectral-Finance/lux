defmodule Lux.Prisms.Shopify.Webhooks.ListWebhooks do
  @moduledoc """
  A prism for listing webhook subscriptions from the Shopify Admin API.

  ## Examples

      iex> ListWebhooks.handler(%{}, %{name: "Agent"})
      {:ok, %{webhooks: [%{"id" => 123, "topic" => "orders/create"}], count: 1}}
  """

  use Lux.Prism,
    name: "List Shopify Webhooks",
    description: "Lists webhook subscriptions from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhooks: %{type: :array, description: "The list of webhook subscriptions"},
        count: %{type: :integer, description: "Number of webhooks returned"}
      },
      required: ["webhooks"]
    }

  alias Lux.Lenses.Shopify.ListWebhooks

  def handler(params, _agent) do
    case ListWebhooks.focus(params) do
      {:ok, webhooks} when is_list(webhooks) ->
        {:ok, %{webhooks: webhooks, count: length(webhooks)}}

      {:ok, webhooks} ->
        {:ok, %{webhooks: webhooks, count: 1}}

      {:error, error} ->
        {:error, error}
    end
  end
end