defmodule Lux.Integrations.MultiChain.ChainAdapter do
  @moduledoc """
  Behaviour for multi-chain adapters.
  """
  @type chain :: :ethereum | :polygon | :arbitrum | :optimism | :base | :bnb
  @type address :: String.t()
  @type block_tag :: "latest" | "pending" | "earliest" | non_neg_integer()
  @type response :: map()

  @callback chain_name() :: String.t()
  @callback chain_id() :: String.t()
  @callback native_currency() :: String.t()
  @callback symbol() :: String.t()
  @callback fetch_balance(address(), block_tag()) :: {:ok, response()} | {:error, String.t()}
  @callback fetch_block_number() :: {:ok, response()} | {:error, String.t()}
  @callback fetch_gas_price() :: {:ok, response()} | {:error, String.t()}
  @callback fetch_tx_count(address(), block_tag()) :: {:ok, response()} | {:error, String.t()}

  @optional_callbacks fetch_tx_count: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.Integrations.MultiChain.ChainAdapter
    end
  end

  @spec wei_to_native(integer() | String.t()) :: float()
  def wei_to_native(wei) when is_binary(wei) do
    wei
    |> String.trim_leading("0x")
    |> Base.decode16(case: :mixed)
    |> case do
      {:ok, bytes} -> :binary.decode_unsigned(bytes) |> wei_to_native()
      _ -> 0.0
    end
  end

  def wei_to_native(wei) when is_integer(wei) and wei >= 0 do
    wei / 1_000_000_000_000_000_000
  end

  @spec native_to_wei(float()) :: integer()
  def native_to_wei(native) when is_number(native) do
    trunc(native * 1_000_000_000_000_000_000)
  end
end
