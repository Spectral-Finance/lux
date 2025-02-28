defmodule Lux.Lenses.Etherscan.AccountLens do
  @moduledoc """
  Lens for fetching account data from the Etherscan API.

  This lens provides access to various account-related endpoints for Ethereum addresses,
  including balance, token balances, transaction lists, and historical balances.

  ## Examples

  ```elixir
  # Get ETH balance for an address
  Lux.Lenses.Etherscan.AccountLens.get_eth_balance(%{
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  })

  # Get token balance for an address
  Lux.Lenses.Etherscan.AccountLens.get_token_balance(%{
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
  })

  # Get normal transactions for an address
  Lux.Lenses.Etherscan.AccountLens.get_normal_transactions(%{
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    startblock: 0,
    endblock: 99999999
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  # List of Pro-only endpoints - only historical balance requires Pro
  @pro_endpoints [
    {:account, :balancehistory}
  ]

  @doc """
  Fetches the Ether balance for a single address.

  ## Parameters

  - `address`: The Ethereum address to get the balance for
  - `tag`: The block number or tag (latest, pending, earliest) (default: "latest")

  ## Returns

  - `{:ok, %{result: balance}}`: Ether balance in Wei on success
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_balance(params) do
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, [:address]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "balance",
        address: params[:address],
        tag: params[:tag] || "latest"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches the Ether balance for multiple addresses in a single call.

  ## Parameters

  - `addresses`: List of Ethereum addresses or comma-separated string (up to 20 addresses)
  - `tag`: The block number or tag (latest, pending, earliest) (default: "latest")

  ## Returns

  - `{:ok, %{result: balances}}`: List of address/balance pairs on success
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_balance_multi(params) do
    with {:ok, _} <- validate_required(params, [:addresses]),
         {:ok, _} <- validate_addresses_list(params[:addresses]) do
      # Format addresses as comma-separated string
      addresses = Enum.join(params[:addresses], ",")

      # Build request parameters
      request_params = %{
        module: "account",
        action: "balancemulti",
        address: addresses,
        tag: params[:tag] || "latest"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches the historical Ether balance for a single address at a specific block height.

  ## Parameters

  - `address`: The Ethereum address to get the balance for
  - `blockno`: The block number to get the balance at

  ## Returns

  - `{:ok, %{result: balance}}`: Ether balance in Wei at the specified block on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_eth_balance_history(params) do
    with {:ok, _} <- validate_required(params, [:address, :blockno]),
         {:ok, _} <- validate_address(params, [:address]),
         {:ok, _} <- validate_integer(params, [:blockno]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:balancehistory, params) do
        # Build request parameters
        request_params = %{
          module: "account",
          action: "balancehistory",
          address: params[:address],
          blockno: params[:blockno]
        }

        # Add contractaddress if provided
        request_params = if params[:contractaddress] do
          Map.put(request_params, :contractaddress, params[:contractaddress])
        else
          request_params
        end

        make_request(request_params)
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  @doc """
  Fetches the ERC-20 token balance for an address.

  ## Parameters

  - `address`: The Ethereum address to get the token balance for
  - `contractaddress`: The token contract address
  - `tag`: The block number or tag (latest, pending, earliest) (default: "latest")

  ## Returns

  - `{:ok, %{result: balance}}`: Token balance on success
  - `{:error, reason}`: Error message on failure
  """
  def get_token_balance(params) do
    with {:ok, _} <- validate_required(params, [:address, :contractaddress]),
         {:ok, _} <- validate_address(params, [:address, :contractaddress]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "tokenbalance",
        address: params[:address],
        contractaddress: params[:contractaddress],
        tag: params[:tag] || "latest"
      }

      # Add contractaddress if provided (already included above)
      request_params = if params[:contractaddress] do
        request_params
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches a list of 'Normal' transactions by address.

  ## Parameters

  - `address`: The Ethereum address to get transactions for
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transactions}}`: List of transactions on success
  - `{:error, reason}`: Error message on failure
  """
  def get_normal_transactions(params) do
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, [:address]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "txlist",
        address: params[:address],
        startblock: params[:startblock] || 0,
        endblock: params[:endblock] || 99999999,
        page: params[:page] || 1,
        offset: params[:offset] || 10,
        sort: params[:sort] || "asc"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches a list of 'Internal' transactions by address.

  ## Parameters

  - `address`: The Ethereum address to get internal transactions for
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transactions}}`: List of internal transactions on success
  - `{:error, reason}`: Error message on failure
  """
  def get_internal_transactions(params) do
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, [:address]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "txlistinternal",
        address: params[:address],
        startblock: params[:startblock] || 0,
        endblock: params[:endblock] || 99999999,
        page: params[:page] || 1,
        offset: params[:offset] || 10,
        sort: params[:sort] || "asc"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches internal transactions by transaction hash.

  ## Parameters

  - `txhash`: Transaction hash

  ## Returns

  - `{:ok, %{result: transactions}}`: List of internal transactions on success
  - `{:error, reason}`: Error message on failure
  """
  def get_internal_transactions_by_hash(params) do
    # Validate required parameters
    validate_required(params, [:txhash])

    # Validate transaction hash format
    validate_tx_hash(params[:txhash])

    # Build request parameters
    request_params = %{
      module: "account",
      action: "txlistinternal",
      txhash: params[:txhash]
    }

    # Make the API request
    make_request(request_params)
  end

  @doc """
  Fetches 'Internal Transactions' by block range.

  ## Parameters

  - `startblock`: Starting block number
  - `endblock`: Ending block number
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transactions}}`: List of internal transactions in the block range on success
  - `{:error, reason}`: Error message on failure
  """
  def get_internal_transactions_by_block_range(params) do
    with {:ok, _} <- validate_required(params, [:startblock, :endblock]),
         {:ok, _} <- validate_integer(params, [:startblock, :endblock, :page, :offset]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "txlistinternal",
        startblock: params[:startblock],
        endblock: params[:endblock],
        page: params[:page] || 1,
        offset: params[:offset] || 10,
        sort: params[:sort] || "asc"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches a list of 'ERC20 - Token Transfer Events' by address.

  ## Parameters

  - `address`: The Ethereum address to get token transfers for
  - `contractaddress`: (Optional) The token contract address to filter by
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transfers}}`: List of ERC20 token transfers on success
  - `{:error, reason}`: Error message on failure
  """
  def get_erc20_token_transfers(params) do
    # Validate required parameters
    unless Map.has_key?(params, :address) do
      raise ArgumentError, "address parameter is required"
    end

    # Validate address format
    address = params[:address]
    unless Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      raise ArgumentError, "Invalid Ethereum address format: #{address}"
    end

    # Validate contract address format if provided
    if Map.has_key?(params, :contractaddress) do
      contract_address = params[:contractaddress]
      unless Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, contract_address) do
        raise ArgumentError, "Invalid contract address format: #{contract_address}"
      end
    end

    # Build request parameters
    base_params = %{
      module: "account",
      action: "tokentx",
      address: address,
      startblock: params[:startblock] || 0,
      endblock: params[:endblock] || 99999999,
      page: params[:page] || 1,
      offset: params[:offset] || 10,
      sort: params[:sort] || "asc",
      chainid: params[:chainid] || "1",
      apikey: api_key()
    }

    # Add contract address if provided
    final_params = if Map.has_key?(params, :contractaddress) do
      Map.put(base_params, :contractaddress, params[:contractaddress])
    else
      base_params
    end

    # Make the API request
    make_request(final_params)
  end

  @doc """
  Fetches a list of 'ERC721 - Token Transfer Events' by address.

  ## Parameters

  - `address`: The Ethereum address to get NFT transfers for
  - `contractaddress`: (Optional) The NFT contract address to filter by
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transfers}}`: List of ERC721 token transfers on success
  - `{:error, reason}`: Error message on failure
  """
  def get_erc721_token_transfers(params) do
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, [:address]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "tokennfttx",
        address: params[:address],
        startblock: params[:startblock] || 0,
        endblock: params[:endblock] || 99999999,
        page: params[:page] || 1,
        offset: params[:offset] || 10,
        sort: params[:sort] || "asc"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches a list of 'ERC1155 - Token Transfer Events' by address.

  ## Parameters

  - `address`: The Ethereum address to get ERC1155 transfers for
  - `contractaddress`: (Optional) The ERC1155 contract address to filter by
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: transfers}}`: List of ERC1155 token transfers on success
  - `{:error, reason}`: Error message on failure
  """
  def get_erc1155_token_transfers(params) do
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, [:address]) do
      # Build request parameters
      request_params = %{
        module: "account",
        action: "token1155tx",
        address: params[:address],
        startblock: params[:startblock] || 0,
        endblock: params[:endblock] || 99999999,
        page: params[:page] || 1,
        offset: params[:offset] || 10,
        sort: params[:sort] || "asc"
      }

      # Add contractaddress if provided
      request_params = if params[:contractaddress] do
        Map.put(request_params, :contractaddress, params[:contractaddress])
      else
        request_params
      end

      make_request(request_params)
    end
  end

  @doc """
  Fetches a list of blocks validated by an address.

  ## Parameters

  - `address`: The Ethereum address of the miner/validator
  - `blocktype`: The type of blocks to fetch, "blocks" for canonical blocks or "uncles" for uncle blocks (default: "blocks")
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)

  ## Returns

  - `{:ok, %{result: blocks}}`: List of blocks validated by the address on success
  - `{:error, reason}`: Error message on failure
  """
  def get_mined_blocks(params) do
    # Validate required parameters
    unless Map.has_key?(params, :address) do
      raise ArgumentError, "address parameter is required"
    end

    # Validate address format
    address = params[:address]
    unless Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      raise ArgumentError, "Invalid Ethereum address format: #{address}"
    end

    # Build request parameters
    request_params = %{
      module: "account",
      action: "getminedblocks",
      address: address,
      blocktype: params[:blocktype] || "blocks",
      page: params[:page] || 1,
      offset: params[:offset] || 10,
      chainid: params[:chainid] || "1",
      apikey: api_key()
    }

    # Make the API request
    make_request(request_params)
  end

  @doc """
  Fetches beacon chain withdrawals by address and block range.

  ## Parameters

  - `address`: The Ethereum address to get withdrawals for
  - `startblock`: Starting block number (default: 0)
  - `endblock`: Ending block number (default: 99999999)
  - `page`: Page number for pagination (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")

  ## Returns

  - `{:ok, %{result: withdrawals}}`: List of beacon chain withdrawals on success
  - `{:error, reason}`: Error message on failure
  """
  def get_beacon_withdrawals(params) do
    # Validate required parameters
    unless Map.has_key?(params, :address) do
      raise ArgumentError, "address parameter is required"
    end

    # Validate address format
    address = params[:address]
    unless Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      raise ArgumentError, "Invalid Ethereum address format: #{address}"
    end

    # Build request parameters
    request_params = %{
      module: "account",
      action: "txsBeaconWithdrawal",
      address: address,
      startblock: params[:startblock] || 0,
      endblock: params[:endblock] || 99999999,
      page: params[:page] || 1,
      offset: params[:offset] || 10,
      sort: params[:sort] || "asc"
    }

    # Make the API request
    make_request(request_params)
  end

  # Check if an endpoint requires a Pro API key
  defp is_pro_endpoint?(endpoint, _params) do
    pro_required = endpoint in @pro_endpoints
    has_pro_key = Config.etherscan_api_key_pro?()

    # Return true if we have a Pro key or if the endpoint doesn't require Pro
    !pro_required || has_pro_key
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

  defp validate_address(params, address_keys) do
    invalid_addresses = Enum.filter(address_keys, fn key ->
      address = params[key]
      address && !Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address)
    end)

    if Enum.empty?(invalid_addresses) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_addresses)
      invalid_address = params[invalid_key]
      raise ArgumentError, "Invalid Ethereum address format: #{invalid_address}"
    end
  end

  defp validate_addresses_list(addresses) when is_list(addresses) do
    invalid_addresses = Enum.filter(addresses, fn address ->
      !Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address)
    end)

    if Enum.empty?(invalid_addresses) do
      {:ok, addresses}
    else
      invalid_address = List.first(invalid_addresses)
      raise ArgumentError, "Invalid Ethereum address format: #{invalid_address}"
    end
  end

  defp validate_addresses_list(_) do
    raise ArgumentError, "addresses must be a list"
  end

  defp validate_integer(params, integer_keys) do
    invalid_integers = Enum.filter(integer_keys, fn key ->
      value = params[key]
      value && !is_integer(value) && !Regex.match?(~r/^\d+$/, to_string(value))
    end)

    if Enum.empty?(invalid_integers) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_integers)
      invalid_value = params[invalid_key]
      raise ArgumentError, "#{invalid_key} must be an integer, got: #{inspect(invalid_value)}"
    end
  end

  # Make API request with the given parameters
  defp make_request(params) do
    # Add API key and chainid to the parameters
    params_with_auth = params
    |> Map.put(:apikey, api_key())
    |> Map.put(:chainid, "1")  # Default to Ethereum mainnet

    case Req.get(@base_url, params: params_with_auth) do
      {:ok, %{status: 200, body: body}} ->
        BaseLens.process_response(body)
      {:ok, response} ->
        {:error, "Unexpected response: #{inspect(response)}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # Helper function to validate transaction hash format
  defp validate_tx_hash(hash) when is_binary(hash) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{64}$/, hash) do
      {:ok, hash}
    else
      raise ArgumentError, "Invalid transaction hash format: #{hash}"
    end
  end

  # Get API key from application config
  defp api_key do
    Config.etherscan_api_key()
  end
end
