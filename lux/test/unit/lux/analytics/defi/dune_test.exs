defmodule Lux.Analytics.Defi.DuneTest do
  use UnitCase, async: true

  alias Lux.Analytics.Defi.Dune

  describe "URL and Header builders" do
    test "constructs Dune endpoints" do
      assert Dune.execute_query_url(123456) == "https://api.dune.com/api/v1/query/123456/execute"
      assert Dune.execution_status_url("exec-abc") == "https://api.dune.com/api/v1/execution/exec-abc/status"
      assert Dune.execution_results_url("exec-abc") == "https://api.dune.com/api/v1/execution/exec-abc/results"
    end

    test "formats auth headers" do
      headers = Dune.auth_headers("dune_secret_key")
      assert {"x-dune-api-key", "dune_secret_key"} in headers
      assert {"Content-Type", "application/json"} in headers
    end
  end

  describe "parse_results/1" do
    test "parses completed query rows and metadata" do
      payload = %{
        "state" => "QUERY_STATE_COMPLETED",
        "result" => %{
          "rows" => [
            %{"wallet" => "0x123", "volume_usd" => 50000.0},
            %{"wallet" => "0x456", "volume_usd" => 25000.0}
          ],
          "metadata" => %{
            "column_names" => ["wallet", "volume_usd"]
          },
          "execution_time_millis" => 350
        }
      }

      assert {:ok, parsed} = Dune.parse_results(payload)
      assert parsed.state == :completed
      assert parsed.row_count == 2
      assert parsed.column_names == ["wallet", "volume_usd"]
      assert parsed.execution_time_millis == 350
    end

    test "parses executing and pending states" do
      assert {:ok, %{state: :executing}} = Dune.parse_results(%{"state" => "QUERY_STATE_EXECUTING"})
      assert {:ok, %{state: :pending}} = Dune.parse_results(%{"state" => "QUERY_STATE_PENDING"})
    end

    test "parses failed query state" do
      payload = %{"state" => "QUERY_STATE_FAILED", "error" => "syntax error at line 4"}
      assert {:error, %{state: :failed, error: "syntax error at line 4"}} = Dune.parse_results(payload)
    end
  end
end
