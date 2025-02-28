defmodule Lux.Lenses.Etherscan.TokenLens do
  @moduledoc """
  Lens for fetching token data from the Etherscan API.

  This lens provides access to various token-related endpoints for Ethereum tokens,
  including ERC20 token supply, token balances, token holder information, and token metadata.

  ## Examples

  ```elixir
  # Get ERC20 token total supply
  Lux.Lenses.Etherscan.TokenLens.get_token_supply(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
  })

  # Get ERC20 token balance for an address
  Lux.Lenses.Etherscan.TokenLens.get_token_balance(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761"
  })

  # Get token holder list
  Lux.Lenses.Etherscan.TokenLens.get_token_holder_list(%{
    contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
    page: 1,
    offset: 10
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  @doc """
  Fetches the current total supply of an ERC20 token.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: total_supply}}`: Total supply on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_supply(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress]),
         {:ok, _} <- validate_address(params, :contractaddress) do
      # Build request parameters
      request_params = %{
        module: "stats",
        action: "tokensupply",
        contractaddress: params[:contractaddress]
      }

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the current balance of an ERC20 token for a specific address.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `address`: The address to check for token balance
  - `tag`: The block parameter, either "latest" or block number (default: "latest")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: balance}}`: Token balance on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_balance(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress, :address]),
         {:ok, _} <- validate_address(params, :contractaddress),
         {:ok, _} <- validate_address(params, :address) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "tokenbalance",
        contractaddress: params[:contractaddress],
        address: params[:address],
        tag: params[:tag] || "latest"
      }

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the historical total supply of an ERC20 token at a specific block.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `blockno`: The block number to check total supply for
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: total_supply}}`: Historical total supply on success
  - `{:error, reason}`: Error message on failure
  """
  def get_historical_token_supply(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress, :blockno]),
         {:ok, _} <- validate_address(params, :contractaddress),
         {:ok, _} <- validate_block_number(params, :blockno) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "tokensupplyhistory",
          contractaddress: params[:contractaddress],
          blockno: params[:blockno]
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the historical balance of an ERC20 token for a specific address at a specific block.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `address`: The address to check for token balance
  - `blockno`: The block number to check balance for
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: balance}}`: Historical token balance on success
  - `{:error, reason}`: Error message on failure
  """
  def get_historical_token_balance(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress, :address, :blockno]),
         {:ok, _} <- validate_address(params, :contractaddress),
         {:ok, _} <- validate_address(params, :address),
         {:ok, _} <- validate_block_number(params, :blockno) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "account",
          action: "tokenbalancehistory",
          contractaddress: params[:contractaddress],
          address: params[:address],
          blockno: params[:blockno]
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the list of token holders for a specific ERC20 token.

  Note: This endpoint is Pro-only.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `page`: The page number (default: 1)
  - `offset`: The number of records per page (default: 10)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: holders}}`: List of token holders on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_holder_list(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress]),
         {:ok, _} <- validate_address(params, :contractaddress) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "token",
          action: "tokenholderlist",
          contractaddress: params[:contractaddress],
          page: params[:page] || 1,
          offset: params[:offset] || 10
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the count of token holders for a specific ERC20 token.

  Note: This endpoint is Pro-only.

  ## Parameters

  - `contractaddress`: The contract address of the ERC20 token
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: count}}`: Number of token holders on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_holder_count(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress]),
         {:ok, _} <- validate_address(params, :contractaddress) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "token",
          action: "tokenholdercount",
          contractaddress: params[:contractaddress]
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches information about a token including project information and social media links.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `contractaddress`: The contract address of the token (ERC20/ERC721/ERC1155)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: info}}`: Token information on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_info(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:contractaddress]),
         {:ok, _} <- validate_address(params, :contractaddress) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "token",
          action: "tokeninfo",
          contractaddress: params[:contractaddress]
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the ERC20 tokens and amounts held by an address.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `address`: The address to check for token holdings
  - `page`: The page number (default: 1)
  - `offset`: The number of records per page (default: 100)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: holdings}}`: List of ERC20 token holdings on success
  - `{:error, reason}`: Error message on failure
  """
  def get_address_erc20_token_holdings(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, :address) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "account",
          action: "addresstokenbalance",
          address: params[:address],
          page: params[:page] || 1,
          offset: params[:offset] || 100
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the ERC721 tokens and amounts held by an address.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `address`: The address to check for token holdings
  - `page`: The page number (default: 1)
  - `offset`: The number of records per page (default: 100)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: holdings}}`: List of ERC721 token holdings on success
  - `{:error, reason}`: Error message on failure
  """
  def get_address_erc721_token_holdings(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, :address) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "account",
          action: "addresstokennftbalance",
          address: params[:address],
          page: params[:page] || 1,
          offset: params[:offset] || 100
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Fetches the ERC721 token inventory of an address, filtered by contract address.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `address`: The address to check for token inventory
  - `contractaddress`: The contract address of the ERC721 token
  - `page`: The page number (default: 1)
  - `offset`: The number of records per page (default: 100, max: 1000)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: inventory}}`: List of ERC721 token inventory on success
  - `{:error, reason}`: Error message on failure
  """
  def get_address_erc721_token_inventory(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:address, :contractaddress]),
         {:ok, _} <- validate_address(params, :address),
         {:ok, _} <- validate_address(params, :contractaddress) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "account",
          action: "addresstokennftinventory",
          address: params[:address],
          contractaddress: params[:contractaddress],
          page: params[:page] || 1,
          offset: params[:offset] || 100
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  # Helper functions for parameter validation
  defp validate_required(params, required_keys) do
    missing_keys = Enum.filter(required_keys, fn key -> !Map.has_key?(params, key) end)

    if Enum.empty?(missing_keys) do
      {:ok, params}
    else
      missing_key = List.first(missing_keys)
      raise ArgumentError, "#{missing_key} parameter is required"
    end
  end

  defp validate_address(params, key) do
    if Map.has_key?(params, key) do
      case BaseLens.validate_eth_address(params[key]) do
        {:ok, _} -> {:ok, params}
        {:error, message} -> raise ArgumentError, message
      end
    else
      {:ok, params}
    end
  end

  defp validate_block_number(params, key) do
    if Map.has_key?(params, key) do
      block_number = params[key]

      if is_integer(block_number) ||
         (is_binary(block_number) && Regex.match?(~r/^\d+$/, block_number)) do
        {:ok, params}
      else
        raise ArgumentError, "#{key} must be a valid integer block number"
      end
    else
      {:ok, params}
    end
  end

  # Check if Pro API key is available
  defp is_pro_api_key do
    Config.etherscan_api_key_pro?()
  end

  # Make API request with the given parameters
  defp make_request(params, network) do
    # Add API key and chainid to the parameters
    params_with_auth = params
    |> Map.put(:apikey, api_key())
    |> Map.put(:chainid, network_to_chain_id(network))

    case Req.get(@base_url, params: params_with_auth) do
      {:ok, %{status: 200, body: body}} ->
        BaseLens.process_response(body)
      {:ok, response} ->
        {:error, "Unexpected response: #{inspect(response)}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # Get API key from application config
  defp api_key do
    Config.etherscan_api_key()
  end

  # Convert network to chain ID
  defp network_to_chain_id(nil), do: "1" # Default to Ethereum mainnet
  defp network_to_chain_id(network), do: Config.etherscan_chain_id(network)
end
