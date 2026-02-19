defmodule Lux.Prisms.EventMonitor.UnsubscribeEventsPrism do
  @moduledoc """
  Prism for removing a smart contract event subscription.

  ## Examples

      iex> Lux.Prisms.EventMonitor.UnsubscribeEventsPrism.run(%{
      ...>   subscription_id: "sub_abc123"
      ...> })
      {:ok, %{subscription_id: "sub_abc123", status: "removed"}}
  """

  use Lux.Prism,
    name: "Unsubscribe from Contract Events",
    description: "Removes a smart contract event monitoring subscription",
    input_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{
          type: :string,
          description: "The subscription ID to remove"
        }
      },
      required: ["subscription_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{
          type: :string,
          description: "The removed subscription ID"
        },
        status: %{
          type: :string,
          description: "Result status"
        }
      },
      required: ["subscription_id", "status"]
    }

  alias Lux.EventMonitor

  @impl true
  def handler(input, ctx) do
    monitor = get_monitor(ctx)
    sub_id = input[:subscription_id] || input["subscription_id"]

    case EventMonitor.unsubscribe(monitor, sub_id) do
      :ok ->
        {:ok, %{subscription_id: sub_id, status: "removed"}}

      {:error, :not_found} ->
        {:error, "Subscription not found: #{sub_id}"}

      {:error, reason} ->
        {:error, "Failed to unsubscribe: #{inspect(reason)}"}
    end
  end

  defp get_monitor(nil), do: Lux.EventMonitor
  defp get_monitor(%{monitor: monitor}), do: monitor
  defp get_monitor(_), do: Lux.EventMonitor
end
