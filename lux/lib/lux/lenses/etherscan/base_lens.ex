defmodule Lux.Lenses.Etherscan.Base do
  @moduledoc """
  Base module for Etherscan API lenses with common functionality.
  """

  @doc """
  Adds the API key to the lens parameters.
  """
  def add_api_key(lens) do
    api_key = Lux.Config.etherscan_api_key()
    params = Map.put(lens.params, :apikey, api_key)
    %{lens | params: params}
  end

  @doc """
  Processes the API response.
  """
  def process_response(response) do
    cond do
      # Handle error object
      Map.has_key?(response, "error") ->
        {:error, response["error"]}

      # Handle successful response
      response["status"] == "1" ->
        {:ok, %{result: response["result"]}}

      # Handle error response
      response["status"] == "0" ->
        # Special handling for Pro API key errors
        result = if is_binary(response["result"]) && String.contains?(response["result"], "Pro subscription") do
          "This endpoint requires an Etherscan Pro API key."
        else
          response["result"]
        end

        {:error, %{message: response["message"], result: result}}

      # Handle unexpected response format
      true ->
        {:error, "Unexpected response format: #{inspect(response)}"}
    end
  end

  @doc """
  Validates an Ethereum address.
  """
  def validate_eth_address(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid Ethereum address format: #{address}"}
    end
  end

  @doc """
  Validates a transaction hash.
  """
  def validate_tx_hash(hash) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{64}$/, hash) do
      {:ok, hash}
    else
      {:error, "Invalid transaction hash format: #{hash}"}
    end
  end

  @doc """
  Validates a block number or tag.
  """
  def validate_block(block) when is_integer(block) and block >= 0 do
    {:ok, Integer.to_string(block)}
  end

  def validate_block(block) when is_binary(block) do
    cond do
      # Block tags
      block in ["latest", "pending", "earliest"] ->
        {:ok, block}

      # Block numbers as strings
      Regex.match?(~r/^\d+$/, block) ->
        {:ok, block}

      # Invalid format
      true ->
        {:error, "Invalid block format: #{block}"}
    end
  end

  def validate_block(block) do
    {:error, "Invalid block format: #{block}"}
  end

  @doc """
  Checks if an endpoint requires a Pro API key.
  """
  def check_pro_endpoint(module, action) do
    pro_endpoints = [
      {"account", "balancehistory"},
      {"account", "addresstokenbalance"},
      {"account", "addresstokennftbalance"},
      {"account", "addresstokennftinventory"},
      {"account", "tokenbalancehistory"},
      {"stats", "chainsize"},
      {"stats", "dailyavgblocksize"},
      {"stats", "dailyavgblocktime"},
      {"stats", "dailyavggaslimit"},
      {"stats", "dailyavggasprice"},
      {"stats", "dailyavghashrate"},
      {"stats", "dailyavgnetdifficulty"},
      {"stats", "dailyblkcount"},
      {"stats", "dailyblockrewards"},
      {"stats", "dailygasused"},
      {"stats", "dailynetworkutilization"},
      {"stats", "dailynewaddress"},
      {"stats", "dailytx"},
      {"stats", "dailytxnfee"},
      {"stats", "dailyuncleblkcount"},
      {"stats", "ethdailyprice"},
      {"stats", "tokensupply"},
      {"stats", "tokensupplyhistory"},
      {"token", "tokeninfo"},
      {"token", "tokenholdercount"},
      {"token", "tokenholderlist"}
    ]

    if {module, action} in pro_endpoints do
      has_pro_key = Lux.Config.etherscan_api_key_pro?()

      if has_pro_key do
        {:ok, true}
      else
        {:error, "This endpoint requires an Etherscan Pro API key."}
      end
    else
      {:ok, true}
    end
  end
end
