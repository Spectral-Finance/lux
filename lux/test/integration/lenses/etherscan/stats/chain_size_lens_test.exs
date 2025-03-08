defmodule Lux.Integration.Etherscan.ChainSizeLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.ChainSize
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthChainSizeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Chain Size API",
      description: "Fetches the size of the Ethereum blockchain, in bytes, over a date range",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "chainsize")
    end
  end

  test "can fetch chain size data with required parameters" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data, chain_size: chain_size_data}} ->
        # Verify the structure of the response
        assert is_list(chain_size_data)

        # If we got data, check the first entry
        if length(chain_size_data) > 0 do
          first_entry = List.first(chain_size_data)
          assert Map.has_key?(first_entry, :utc_date)
          assert Map.has_key?(first_entry, :block_number)
          assert Map.has_key?(first_entry, :chain_size_bytes)

          # Chain size should be a large number (more than 100 GB in bytes)
          assert is_integer(first_entry.chain_size_bytes)
          assert first_entry.chain_size_bytes > 100 * 1024 * 1024 * 1024 # More than 100 GB

          # Log the data for informational purposes
          IO.puts("Date: #{first_entry.utc_date}")
          IO.puts("Block Number: #{first_entry.block_number}")
          IO.puts("Chain Size: #{first_entry.chain_size_bytes / (1024 * 1024 * 1024)} GB")
        end

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          IO.puts("Chain Size API requires a Pro API key: #{error_message}")
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end

  test "can fetch chain size data with all parameters" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      clienttype: "geth",
      syncmode: "default",
      sort: "asc",
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data}} ->
        assert is_list(chain_size_data)
        assert true

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          IO.puts("Chain Size API requires a Pro API key: #{error_message}")
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end

  test "can specify different sort order" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      sort: "desc",
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data}} ->
        assert is_list(chain_size_data)
        assert true

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          IO.puts("Chain Size API requires a Pro API key: #{error_message}")
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthChainSizeLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthChainSizeLens, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end

  test "returns error for missing required parameters" do
    # Missing startdate and enddate
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for missing required parameters
        assert error != nil

      _ ->
        flunk("Expected an error for missing required parameters")
    end
  end
end
