defmodule Lux.Lenses.Etherscan.BlockLens do
  @moduledoc """
  Lens for fetching block data from the Etherscan API.

  This lens provides access to various block-related endpoints for Ethereum blocks,
  including block rewards, transaction counts, and block timing information.

  ## Examples

  ```elixir
  # Get block and uncle rewards by block number
  Lux.Lenses.Etherscan.BlockLens.get_block_reward(%{
    blockno: 2165403
  })

  # Get block transactions count by block number
  Lux.Lenses.Etherscan.BlockLens.get_block_txns_count(%{
    blockno: 2165403
  })

  # Get estimated block countdown time by block number
  Lux.Lenses.Etherscan.BlockLens.get_block_countdown(%{
    blockno: 16701588
  })

  # Get block number by timestamp
  Lux.Lenses.Etherscan.BlockLens.get_block_no_by_time(%{
    timestamp: 1578638524,
    closest: "before"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  # List of Pro-only endpoints
  @pro_endpoints [
    {:stats, :dailyavgblocksize},
    {:stats, :dailyblkcount},
    {:stats, :dailyblockrewards},
    {:stats, :dailyavgblocktime},
    {:stats, :dailyuncleblkcount}
  ]

  @doc """
  Fetches the block reward and uncle block rewards for a specific block.

  ## Parameters

  - `blockno`: Block number
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: block_reward_info}}`: Block reward information on success
  - `{:error, reason}`: Error message on failure
  """
  def get_block_reward(params) do
    with {:ok, _} <- validate_required(params, [:blockno]),
         {:ok, _} <- validate_integer(params, [:blockno]) do
      # Build request parameters
      request_params = %{
        module: "block",
        action: "getblockreward",
        blockno: params[:blockno]
      }

      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the number of transactions in a specified block.

  ## Parameters

  - `blockno`: Block number
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: transaction_count}}`: Number of transactions in the block on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint is only available on Etherscan, chainId 1 (Ethereum mainnet).
  """
  def get_block_txns_count(params) do
    with {:ok, _} <- validate_required(params, [:blockno]),
         {:ok, _} <- validate_integer(params, [:blockno]) do
      # Build request parameters
      request_params = %{
        module: "block",
        action: "getblocktxnscount",
        blockno: params[:blockno]
      }

      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the estimated time remaining until a certain block is mined.

  ## Parameters

  - `blockno`: Block number
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: countdown_info}}`: Estimated time remaining in seconds on success
  - `{:error, reason}`: Error message on failure
  """
  def get_block_countdown(params) do
    with {:ok, _} <- validate_required(params, [:blockno]),
         {:ok, _} <- validate_integer(params, [:blockno]) do
      # Build request parameters
      request_params = %{
        module: "block",
        action: "getblockcountdown",
        blockno: params[:blockno]
      }

      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the block number that was mined at a certain timestamp.

  ## Parameters

  - `timestamp`: Unix timestamp in seconds
  - `closest`: The closest available block to the provided timestamp, either "before" or "after" (default: "before")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: block_number}}`: Block number on success
  - `{:error, reason}`: Error message on failure
  """
  def get_block_no_by_time(params) do
    with {:ok, _} <- validate_required(params, [:timestamp]),
         {:ok, _} <- validate_integer(params, [:timestamp]) do
      # Build request parameters
      request_params = %{
        module: "block",
        action: "getblocknobytime",
        timestamp: params[:timestamp],
        closest: params[:closest] || "before"
      }

      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the daily average block size within a date range.

  ## Parameters

  - `startdate`: Starting date in yyyy-MM-dd format
  - `enddate`: Ending date in yyyy-MM-dd format
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: daily_avg_block_sizes}}`: Daily average block sizes on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_daily_avg_block_size(params) do
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, [:startdate, :enddate]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:dailyavgblocksize, params) do
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavgblocksize",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        make_request(request_params, params[:network])
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  @doc """
  Fetches the number of blocks mined daily and the amount of block rewards.

  ## Parameters

  - `startdate`: Starting date in yyyy-MM-dd format
  - `enddate`: Ending date in yyyy-MM-dd format
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: daily_block_counts}}`: Daily block counts and rewards on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_daily_block_count(params) do
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, [:startdate, :enddate]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:dailyblkcount, params) do
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyblkcount",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        make_request(request_params, params[:network])
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  @doc """
  Fetches the amount of block rewards distributed to miners daily.

  ## Parameters

  - `startdate`: Starting date in yyyy-MM-dd format
  - `enddate`: Ending date in yyyy-MM-dd format
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: daily_block_rewards}}`: Daily block rewards on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_daily_block_rewards(params) do
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, [:startdate, :enddate]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:dailyblockrewards, params) do
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyblockrewards",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        make_request(request_params, params[:network])
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  @doc """
  Fetches the daily average time needed for a block to be successfully mined.

  ## Parameters

  - `startdate`: Starting date in yyyy-MM-dd format
  - `enddate`: Ending date in yyyy-MM-dd format
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: daily_avg_block_times}}`: Daily average block times on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_daily_avg_block_time(params) do
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, [:startdate, :enddate]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:dailyavgblocktime, params) do
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavgblocktime",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        make_request(request_params, params[:network])
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  @doc """
  Fetches the number of uncle blocks mined daily and the amount of uncle block rewards.

  ## Parameters

  - `startdate`: Starting date in yyyy-MM-dd format
  - `enddate`: Ending date in yyyy-MM-dd format
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: daily_uncle_block_counts}}`: Daily uncle block counts and rewards on success
  - `{:error, reason}`: Error message on failure

  ## Note

  This endpoint requires an Etherscan Pro API key.
  """
  def get_daily_uncle_block_count(params) do
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, [:startdate, :enddate]) do
      # Check if Pro API key is required
      if is_pro_endpoint?(:dailyuncleblkcount, params) do
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyuncleblkcount",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        make_request(request_params, params[:network])
      else
        {:error, %{message: "NOTOK", result: "This endpoint requires an Etherscan Pro API key."}}
      end
    end
  end

  # Check if an endpoint requires a Pro API key
  defp is_pro_endpoint?(endpoint, _params) do
    pro_required = Enum.any?(@pro_endpoints, fn {module, action} ->
      action == endpoint && (module == :stats || module == :block)
    end)
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

  defp validate_date_format(params, date_keys) do
    invalid_dates = Enum.filter(date_keys, fn key ->
      value = params[key]
      value && !Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, to_string(value))
    end)

    if Enum.empty?(invalid_dates) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_dates)
      invalid_value = params[invalid_key]
      raise ArgumentError, "#{invalid_key} must be in yyyy-MM-dd format, got: #{inspect(invalid_value)}"
    end
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
