defmodule Lux.NFTMarketplace.Sale do
  @moduledoc """
  Schema and functions for NFT sale/transaction data.
  """

  defstruct [
    :transaction_hash,
    :token_id,
    :collection_slug,
    :price,
    :currency,
    :buyer,
    :seller,
    :marketplace,
    :timestamp,
    :block_number
  ]

  @type t :: %__MODULE__{
    transaction_hash: String.t(),
    token_id: String.t(),
    collection_slug: String.t(),
    price: Decimal.t(),
    currency: String.t(),
    buyer: String.t(),
    seller: String.t(),
    marketplace: String.t(),
    timestamp: DateTime.t(),
    block_number: non_neg_integer()
  }

  @doc """
  Creates a new Sale struct.
  """
  def new(attrs) do
    struct!(__MODULE__, Map.merge(defaults(), attrs))
  end

  @doc """
  Calculates the sale price in a common currency (e.g., ETH).
  """
  def normalized_price(%__MODULE__{price: price, currency: "ETH"}), do: price
  def normalized_price(%__MODULE__{price: price, currency: "WETH"}), do: price
  def normalized_price(%__MODULE__{price: _price, currency: _other}) do
    # In a real implementation, this would use a price oracle or conversion rate
    nil
  end

  defp defaults do
    %{}
  end
end