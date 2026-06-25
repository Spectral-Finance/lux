defmodule Lux.NFTMarketplace.Collection do
  @moduledoc """
  Schema and functions for NFT collection data aggregation.
  """

  alias Lux.NFTMarketplace.Trait

 computed_schema = [
    :slug,
    :name,
    :description,
    :contract_address,
    :blockchain,
    :created_date,
    :floor_price,
    :floor_price_currency,
    :total_supply,
    :num_owners,
    :one_volume,
    :one_volume_currency,
    :marketplace,
    :image_url,
    :external_url,
    :traits,
    :last_updated
  ]

  defstruct computed_schema

  @type t :: %__MODULE__{
    slug: String.t(),
    name: String.t(),
    description: String.t(),
    contract_address: String.t(),
    blockchain: String.t(),
    created_date: DateTime.t(),
    floor_price: Decimal.t() | nil,
    floor_price_currency: String.t(),
    total_supply: non_neg_integer(),
    num_owners: non_neg_integer(),
    one_volume: Decimal.t() | nil,
    one_volume_currency: String.t(),
    marketplace: String.t(),
    image_url: String.t() | nil,
    external_url: String.t() | nil,
    traits: list(Trait.t()),
    last_updated: DateTime.t()
  }

  @doc """
  Creates a new Collection struct with default values.
  """
  def new(attrs \\ %{}) do
    struct!(__MODULE__, Map.merge(defaults(), attrs))
  end

  defp defaults do
    %{
      floor_price: nil,
      one_volume: nil,
      image_url: nil,
      external_url: nil,
      traits: [],
      last_updated: DateTime.utc_now()
    }
  end
end