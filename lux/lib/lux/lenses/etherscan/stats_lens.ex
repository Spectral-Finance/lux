defmodule Lux.Lenses.Etherscan.StatsLens do
  @moduledoc """
  Lens for fetching network statistics data from the Etherscan API.

  This lens provides access to various statistics-related endpoints for Ethereum,
  including Ether supply, price data, network metrics, and historical statistics.

  ## Examples

  ```elixir
  # Get total supply of Ether
  Lux.Lenses.Etherscan.StatsLens.get_eth_supply()

  # Get Ether last price
  Lux.Lenses.Etherscan.StatsLens.get_eth_price()

  # Get daily transaction count
  Lux.Lenses.Etherscan.StatsLens.get_daily_tx_count(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31",
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  @doc """
  Returns the current amount of Ether in circulation excluding ETH2 Staking rewards and EIP1559 burnt fees.

  ## Parameters

  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: supply}}`: Total Ether supply in wei
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_supply(params \\ %{}) do
    # Build request parameters
    request_params = %{
      module: "stats",
      action: "ethsupply"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Returns the current amount of Ether in circulation, ETH2 Staking rewards, EIP1559 burnt fees,
  and total withdrawn ETH from the beacon chain.

  ## Parameters

  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: supply_data}}`: Detailed Ether supply data
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_supply2(params \\ %{}) do
    # Build request parameters
    request_params = %{
      module: "stats",
      action: "ethsupply2"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Returns the latest price of 1 ETH.

  ## Parameters

  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: price_data}}`: Current ETH price data
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_price(params \\ %{}) do
    # Build request parameters
    request_params = %{
      module: "stats",
      action: "ethprice"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Returns the size of the Ethereum blockchain, in bytes, over a date range.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `clienttype`: The Ethereum node client to use, either "geth" or "parity"
  - `syncmode`: The type of node to run, either "default" or "archive"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: chain_size_data}}`: Ethereum blockchain size data
  - `{:error, reason}`: Error message on failure
  """
  def get_chain_size(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate, :clienttype, :syncmode]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate),
         {:ok, _} <- validate_client_type(params[:clienttype]),
         {:ok, _} <- validate_sync_mode(params[:syncmode]) do
      # Build request parameters
      request_params = %{
        module: "stats",
        action: "chainsize",
        startdate: params[:startdate],
        enddate: params[:enddate],
        clienttype: params[:clienttype],
        syncmode: params[:syncmode],
        sort: params[:sort] || "asc"
      }

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Returns the total number of discoverable Ethereum nodes.

  ## Parameters

  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: node_count}}`: Total number of Ethereum nodes
  - `{:error, reason}`: Error message on failure
  """
  def get_node_count(params \\ %{}) do
    # Build request parameters
    request_params = %{
      module: "stats",
      action: "nodecount"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Returns the amount of transaction fees paid to miners per day.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: txn_fee_data}}`: Daily transaction fee data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_txn_fee(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailytxnfee",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the number of new Ethereum addresses created per day.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: new_address_data}}`: Daily new address count data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_new_address(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailynewaddress",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the daily average gas used over gas limit, in percentage.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: utilization_data}}`: Daily network utilization data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_network_utilization(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailynetutilization",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the historical measure of processing power of the Ethereum network.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: hashrate_data}}`: Daily average hash rate data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_avg_hashrate(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavghashrate",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the number of transactions performed on the Ethereum blockchain per day.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: tx_count_data}}`: Daily transaction count data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_tx_count(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailytx",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the historical mining difficulty of the Ethereum network.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: difficulty_data}}`: Daily average network difficulty data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_avg_network_difficulty(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavgnetdifficulty",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the historical price of 1 ETH.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: price_data}}`: Historical ETH price data
  - `{:error, reason}`: Error message on failure
  """
  def get_eth_historical_price(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "ethdailyprice",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
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

  defp validate_date_format(params, key) do
    if Map.has_key?(params, key) do
      date = params[key]
      # Check if date matches yyyy-MM-dd format
      if Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, date) do
        {:ok, params}
      else
        raise ArgumentError, "#{key} must be in yyyy-MM-dd format, e.g., 2023-01-31"
      end
    else
      {:ok, params}
    end
  end

  defp validate_client_type(client_type) do
    if client_type in ["geth", "parity"] do
      {:ok, client_type}
    else
      raise ArgumentError, "clienttype must be either 'geth' or 'parity'"
    end
  end

  defp validate_sync_mode(sync_mode) do
    if sync_mode in ["default", "archive"] do
      {:ok, sync_mode}
    else
      raise ArgumentError, "syncmode must be either 'default' or 'archive'"
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
