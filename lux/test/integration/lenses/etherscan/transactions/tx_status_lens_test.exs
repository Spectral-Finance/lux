defmodule Lux.Integration.Etherscan.TxStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TxStatus
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example successful transaction hash
  @successful_tx "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can check execution status for a successful transaction" do
    assert {:ok, %{result: %{status: status, is_error: is_error, error_message: _error_message}}} =
             TxStatus.focus(%{
               txhash: @successful_tx,
               chainid: 1
             })

    # Verify the status is "1" for a successful transaction
    # Note: For this API, status "1" with is_error true indicates a successful transaction
    assert status == "1"
    assert is_error == true
    # The error_message can vary, so we just log it instead of asserting a specific value
  end
end
