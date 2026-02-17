defmodule Lux.Prisms.Hyperliquid.HyperliquidPositionManagerPrism do
  @moduledoc """
  A prism that manages positions on the Hyperliquid exchange with leverage control and margin management.

  ## Example

      # Open a position
      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagerPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: true,
      ...>   sz: 0.0051,
      ...>   leverage: 2,
      ...>   margin: 1000.0
      ...> })
      {:ok,
       %{
         "status" => "success",
         "position_result" => %{
           # ... response from Hyperliquid
         }
       }}

      # Close a position
      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagerPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: false,
      ...>   sz: 0.0051,
      ...>   leverage: 2,
      ...>   margin: 1000.0
      ...> })
      {:ok,
       %{
         "status" => "success",
         "position_result" => %{
           # ... response from Hyperliquid
         }
       }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Position Management",
    description: "Manages positions on Hyperliquid exchange with leverage control and margin management",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        is_buy: %{
          type: :boolean,
          description: "True for buy positions, false for sell positions"
        },
        sz: %{
          type: :number,
          description: "Position size in base currency"
        },
        leverage: %{
          type: :integer,
          description: "Leverage level for the position"
        },
        margin: %{
          type: :number,
          description: "Margin amount for the position"
        }
      },
      required: [:coin, :is_buy, :sz, :leverage, :margin]
    }

  def run(params) do
    private_key = Application.get_env(:hyperliquid, :hyperliquid_private_key)
    address = Application.get_env(:hyperliquid, :hyperliquid_address)

    # Construct the request payload
    payload = %{
      coin: params[:coin],
      is_buy: params[:is_buy],
      sz: params[:sz],
      leverage: params[:leverage],
      margin: params[:margin]
    }

    # Make the API call to open or close a position
    case HTTPoison.post!("https://api.hyperliquid.finance/v1/position", Jason.encode!(payload), headers: [{"Authorization", "Bearer #{private_key}"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, %{"status" => "success", "position_result" => Poison.decode!(body)}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{"status" => "failure", "message" => reason}}
    end
  end
end

def get_positions(params) do
    private_key = Application.get_env(:hyperliquid, :hyperliquid_private_key)
    address = Application.get_env(:hyperliquid, :hyperliquid_address)

    # Construct the request payload
    payload = %{
      coin: params[:coin],
      is_buy: params[:is_buy],
      sz: params[:sz],
      leverage: params[:leverage],
      margin: params[:margin]
    }

    # Make the API call to open a position
    response = HyperliquidAPI.open_position(private_key, address, payload)

    case response do
      {:ok, data} ->
        {:ok, %{"status" => "success", "position_result" => data}}

      {:error, error} ->
        {:error, %{"status" => "failure", "error" => error}}
    end
  end