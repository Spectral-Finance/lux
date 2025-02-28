defmodule Lux.Lenses.Etherscan.BaseLens do
  @moduledoc """
  Base module for Etherscan API interactions.

  This module provides common functionality for all Etherscan API lenses,
  including authentication, error handling, and response transformation.

  It is not meant to be used directly, but rather extended by specific
  Etherscan API lenses.
  """

  @doc """
  Adds the Etherscan API key to the lens parameters.
  """
  def add_api_key(lens) do
    Map.update!(lens, :params, fn params ->
      Map.put(params, :apikey, Lux.Config.etherscan_api_key())
    end)
  end

  @doc """
  Common after_focus implementation for Etherscan API responses.
  Handles standard Etherscan response format and error cases.
  """
  def process_response(%{"status" => "1", "message" => "OK", "result" => result}) do
    {:ok, %{result: result}}
  end

  def process_response(%{"status" => "0", "message" => message, "result" => result}) do
    {:error, %{message: message, result: result}}
  end

  def process_response(%{"error" => error}) do
    {:error, error}
  end

  def process_response(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  @doc """
  Builds the URL for the Etherscan API.

  ## Parameters

  * `network` - The network to use, either as an atom (e.g., :ethereum, :polygon) or as a chain ID integer
  """
  def build_url(network \\ :ethereum) do
    Lux.Config.etherscan_api_url(network)
  end

  @doc """
  Adds the chain ID parameter to the lens parameters based on the network.
  """
  def add_chain_id(params, network \\ :ethereum) do
    Map.put(params, :chainid, Lux.Config.etherscan_chain_id(network))
  end

  @doc """
  Validates an Ethereum address format.
  """
  def validate_eth_address(address) when is_binary(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid Ethereum address format: #{address}"}
    end
  end

  @doc """
  Validates a transaction hash format.
  """
  def validate_tx_hash(hash) when is_binary(hash) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{64}$/, hash) do
      {:ok, hash}
    else
      {:error, "Invalid transaction hash format: #{hash}"}
    end
  end

  @doc """
  Validates a block number or block tag.
  """
  def validate_block(block) when is_binary(block) do
    case block do
      "latest" -> {:ok, block}
      "pending" -> {:ok, block}
      "earliest" -> {:ok, block}
      _ ->
        if Regex.match?(~r/^[0-9]+$/, block) do
          {:ok, block}
        else
          {:error, "Invalid block format: #{block}"}
        end
    end
  end

  def validate_block(block) when is_integer(block) and block >= 0 do
    {:ok, Integer.to_string(block)}
  end

  def validate_block(block) do
    {:error, "Invalid block format: #{inspect(block)}"}
  end
end
