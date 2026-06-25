defmodule Lux.NFTMarketplace.Listing do
  @moduledoc """
  Schema and functions for NFT listing data.
  """

  defstruct [
    :token_id,
    :collection_slug,
    :price,
    :currency,
    :seller,
    :marketplace,
    :listing_url,
    :created_date,
    :expiration_date,
    :status
  ]

  @type t :: %__MODULE__{
    token_id: String.t(),
    collection_slug: String.t(),
    price: Decimal.t(),
    currency: String.t(),
    seller: String.t(),
    marketplace: String.t(),
    listing_url: String.t(),
    created_date: DateTime.t(),
    expiration_date: DateTime.t() | nil,
    status: :active | :expired | :sold | :cancelled
  }

  @doc """
  Creates a new Listing struct.
  """
  def new(attrs) do
    struct!(__MODULE__, Map.merge(defaults(), attrs))
  end

  @doc """
  Checks if a listing is active.
  """
  def active?(%__MODULE__{status: :active}), do: true
  def active?(_), do: false

  @doc """
  Checks if a listing has expired.
  """
  def expired?(%__MODULE__{expiration_date: nil}), do: false
  def expired?(%__MODULE__{expiration_date: exp}) do
    DateTime.compare(exp, DateTime.utc_now()) == :lt
  end

  defp defaults do
    %{status: :active}
  end
end