defmodule Lux.Lenses.Etherscan.TransactionLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.TransactionLens

  # Add a delay between API calls to avoid rate limiting
  @delay_ms 300

  # Helper function to set up the API key for tests
  setup do
    # Store original API key configuration
    original_api_key = Application.get_env(:lux, :api_keys)

    # Set API key for testing from environment variable or use a default test key
    api_key = System.get_env("ETHERSCAN_API_KEY") || "YourApiKeyToken"

    # Check if we should use Pro API key for testing
    is_pro = System.get_env("ETHERSCAN_API_KEY_PRO") == "true"

    # Set the API key and Pro flag
    Application.put_env(:lux, :api_keys, [etherscan: api_key, etherscan_pro: is_pro])

    # Add a delay to avoid hitting rate limits
    Process.sleep(@delay_ms)

    on_exit(fn ->
      # Restore original API key configuration
      Application.put_env(:lux, :api_keys, original_api_key)
    end)

    :ok
  end

  # Helper function to add delay between API calls
  defp with_rate_limit(fun) do
    Process.sleep(@delay_ms)
    fun.()
  end

  describe "get_contract_execution_status/1" do
    @tag :integration
    test "fetches contract execution status for a valid transaction hash" do
      # Using the example transaction hash from the documentation
      txhash = "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"

      result = with_rate_limit(fn -> TransactionLens.get_contract_execution_status(%{txhash: txhash}) end)

      IO.puts("\n=== Contract Execution Status Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      assert is_map(result_data)
      assert Map.has_key?(result_data, "isError")

      # The isError field should be either "0" (success) or "1" (error)
      is_error = result_data["isError"]
      assert is_error == "0" || is_error == "1"
    end

    test "raises error when txhash is missing" do
      assert_raise ArgumentError, "txhash parameter is required", fn ->
        TransactionLens.get_contract_execution_status(%{})
      end
    end

    test "raises error when txhash is invalid" do
      assert_raise ArgumentError, "Invalid transaction hash format: invalid", fn ->
        TransactionLens.get_contract_execution_status(%{txhash: "invalid"})
      end
    end
  end

  describe "get_tx_receipt_status/1" do
    @tag :integration
    test "fetches transaction receipt status for a valid transaction hash" do
      # Using the example transaction hash from the documentation
      txhash = "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"

      result = with_rate_limit(fn -> TransactionLens.get_tx_receipt_status(%{txhash: txhash}) end)

      IO.puts("\n=== Transaction Receipt Status Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      assert is_map(result_data)
      assert Map.has_key?(result_data, "status")

      # The status field should be either "0" (failure) or "1" (success)
      status = result_data["status"]
      assert status == "0" || status == "1"
    end

    test "raises error when txhash is missing" do
      assert_raise ArgumentError, "txhash parameter is required", fn ->
        TransactionLens.get_tx_receipt_status(%{})
      end
    end

    test "raises error when txhash is invalid" do
      assert_raise ArgumentError, "Invalid transaction hash format: invalid", fn ->
        TransactionLens.get_tx_receipt_status(%{txhash: "invalid"})
      end
    end
  end
end
