defmodule Lux.Integration.Etherscan.TxReceiptStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TxReceiptStatus
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example successful transaction hash
  @successful_tx "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can check receipt status for a successful transaction" do
    assert {:ok, %{result: %{status: status, is_success: is_success}}} =
             TxReceiptStatus.focus(%{
               txhash: @successful_tx,
               chainid: 1
             })

    # Verify the status is "1" for a successful transaction
    assert status == "1"
    assert is_success == true
  end
end
