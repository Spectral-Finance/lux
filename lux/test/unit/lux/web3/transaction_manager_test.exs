defmodule Lux.Web3.TransactionManagerTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.TransactionManagerPrism
  alias Lux.Web3.Gas
  alias Lux.Web3.RPC
  alias Lux.Web3.TransactionBatch
  alias Lux.Web3.TransactionManager

  @from "0x1111111111111111111111111111111111111111"
  @to "0x2222222222222222222222222222222222222222"
  @batch "0x3333333333333333333333333333333333333333"
  @hash <<0x12, 0x34>> |> ExKeccak.hash_256() |> Ethers.Utils.hex_encode()

  setup_all do
    {:ok, _} = Application.ensure_all_started(:req)
    :ok
  end

  defp tx, do: %{"from" => @from, "to" => @to, "value" => "0x1"}

  defp opts(overrides \\ %{}) do
    caller = self()

    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, payload, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(payload)
      method = body["method"]
      params = body["params"]
      send(caller, {:rpc, method, params, conn.host})
      send(caller, {:authorization, conn.host, Plug.Conn.get_req_header(conn, "authorization")})

      result =
        case Map.fetch(overrides, method) do
          {:ok, fun} when is_function(fun, 1) -> fun.(params)
          {:ok, value} -> value
          :error -> default_result(method, params)
        end

      case result do
        {:rpc_error, error} ->
          Req.Test.json(conn, %{jsonrpc: "2.0", id: body["id"], error: error})

        {:status, status} ->
          Plug.Conn.send_resp(conn, status, "unavailable")

        {:transport_error, reason} ->
          Req.Test.transport_error(conn, reason)

        :bad_id ->
          Req.Test.json(conn, %{jsonrpc: "2.0", id: -1, result: "0x1"})

        value ->
          Req.Test.json(conn, %{jsonrpc: "2.0", id: body["id"], result: value})
      end
    end)

    [
      rpc_url: "https://public.example",
      req_options: [plug: {Req.Test, __MODULE__}],
      private_req_options: [plug: {Req.Test, __MODULE__}]
    ]
  end

  defp default_result("eth_feeHistory", _),
    do: %{"baseFeePerGas" => ["0x64", "0x64"], "reward" => [["0x1", "0x2", "0x3"]]}

  defp default_result("eth_chainId", _), do: "0x1"
  defp default_result("eth_getTransactionCount", _), do: "0x7"
  defp default_result("eth_call", _), do: "0x"
  defp default_result("eth_estimateGas", _), do: "0x5208"
  defp default_result("eth_getBalance", _), do: "0x1000000000000000000"
  defp default_result("eth_getCode", _), do: "0x6000"
  defp default_result("eth_sendRawTransaction", _), do: @hash

  test "preflight uses pending nonce, simulation, a gas buffer and integer cost analysis" do
    assert {:ok, plan} = TransactionManager.prepare(tx(), opts())
    assert plan.transaction["nonce"] == "0x7"
    assert plan.transaction["chainId"] == "0x1"
    assert plan.transaction["type"] == "0x2"
    assert plan.transaction["gas"] == Gas.hex(25_200)
    assert plan.cost.required_balance_wei == plan.cost.maximum_fee_wei + 1
    assert_received {:rpc, "eth_getTransactionCount", [@from, "pending"], _}
    assert_received {:rpc, "eth_call", [_, "pending"], _}
    assert_received {:rpc, "eth_estimateGas", [_, "pending"], _}
    refute_received {:rpc, "eth_sendRawTransaction", _, _}
  end

  test "supplied replacement nonce and fee caps survive preflight" do
    replacement =
      Map.merge(tx(), %{
        "nonce" => 3,
        "maxFeePerGas" => 2_000_000_000,
        "maxPriorityFeePerGas" => 1_000_000_000
      })

    assert {:ok, plan} = TransactionManager.prepare(replacement, opts())
    assert plan.transaction["nonce"] == "0x3"
    assert plan.transaction["maxFeePerGas"] == Gas.hex(2_000_000_000)
    refute_received {:rpc, "eth_getTransactionCount", _, _}
  end

  test "invalid transactions are rejected before contacting the node" do
    options = opts()

    for invalid <- [
          nil,
          %{},
          Map.put(tx(), "from", "invalid"),
          Map.put(tx(), "data", "0x1"),
          Map.put(tx(), "gasPrice", "0x1"),
          Map.put(tx(), "value", -1),
          Map.put(tx(), "accessList", [%{"address" => @to, "storageKeys" => ["0x1"]}])
        ] do
      assert {:error, _} = TransactionManager.prepare(invalid, options)
    end

    refute_received {:rpc, _, _, _}
  end

  test "chain mismatch and incomplete or nonviable fee caps fail preflight" do
    options = opts()

    assert {:error, :chain_id_mismatch} =
             TransactionManager.prepare(Map.put(tx(), "chainId", 2), options)

    assert {:error, :both_fee_caps_required} =
             TransactionManager.prepare(Map.put(tx(), "maxFeePerGas", 200), options)

    assert {:error, :invalid_fee_caps} =
             TransactionManager.prepare(
               Map.merge(tx(), %{"maxFeePerGas" => 99, "maxPriorityFeePerGas" => 1}),
               options
             )

    refute_received {:rpc, "eth_call", _, _}
  end

  test "reverts preserve node details and prevent signing or submission" do
    error = %{"code" => 3, "message" => "execution reverted", "data" => "0x1234"}
    options = opts(%{"eth_call" => {:rpc_error, error}})

    assert {:error, {:rpc, ^error}} =
             TransactionManager.execute(tx(), fn _ -> flunk("must not sign") end, options)

    refute_received {:rpc, "eth_sendRawTransaction", _, _}
    refute_received {:rpc, "eth_estimateGas", _, _}
  end

  test "insufficient native funds, a small gas limit and bad buffers are rejected" do
    assert {:error, :insufficient_balance} =
             TransactionManager.prepare(tx(), opts(%{"eth_getBalance" => "0x0"}))

    assert {:error, :gas_limit_below_estimate} =
             TransactionManager.prepare(Map.put(tx(), "gas", 20_000), opts())

    assert {:error, :invalid_gas_buffer} =
             TransactionManager.prepare(tx(), Keyword.put(opts(), :gas_buffer_percent, -1))
  end

  test "a malformed estimator response cannot create a successful plan" do
    for value <- ["0x", "invalid", "0x0", nil] do
      assert {:error, _} = TransactionManager.prepare(tx(), opts(%{"eth_estimateGas" => value}))
    end
  end

  test "protected submission requires an explicit private RPC" do
    assert {:error, {:private_rpc_url, :required}} = TransactionManager.submit("0x1234", opts())
    refute_received {:rpc, "eth_sendRawTransaction", _, _}
  end

  test "private submission routes only to the private RPC" do
    options = Keyword.put(opts(), :private_rpc_url, "https://private.example")
    assert {:ok, @hash} = TransactionManager.submit("0x1234", options)
    assert_received {:rpc, "eth_sendRawTransaction", ["0x1234"], "private.example"}
    refute_received {:rpc, "eth_sendRawTransaction", _, "public.example"}
  end

  test "a private HTTP failure is neither retried nor sent to the public RPC" do
    options =
      opts(%{"eth_sendRawTransaction" => {:status, 503}})
      |> Keyword.put(:private_rpc_url, "https://private.example")

    assert {:error,
            {:submission_unknown, %{transaction_hash: @hash, reason: {:http_status, 503}}}} =
             TransactionManager.submit("0x1234", options)

    assert_received {:rpc, "eth_sendRawTransaction", _, "private.example"}
    refute_received {:rpc, "eth_sendRawTransaction", _, _}
  end

  test "private routing isolates endpoint authentication and verifies the returned hash" do
    options =
      opts()
      |> Keyword.put(:private_rpc_url, "https://private.example")
      |> Keyword.put(:req_options,
        plug: {Req.Test, __MODULE__},
        headers: [authorization: "public-test-header"]
      )

    assert {:ok, @hash} = TransactionManager.submit("0x1234", options)
    assert_received {:authorization, "private.example", []}

    options =
      Keyword.put(options, :private_req_options,
        plug: {Req.Test, __MODULE__},
        url: "https://public.example",
        headers: [authorization: "private-test-header"]
      )

    assert {:ok, @hash} = TransactionManager.submit("0x1234", options)
    assert_received {:authorization, "private.example", ["private-test-header"]}

    options =
      opts(%{"eth_sendRawTransaction" => "0x" <> String.duplicate("ab", 32)})
      |> Keyword.put(:private_rpc_url, "https://private.example")

    assert {:error,
            {:submission_unknown,
             %{transaction_hash: @hash, reason: :unexpected_transaction_hash}}} =
             TransactionManager.submit("0x1234", options)
  end

  test "a private transport timeout returns the local hash without a retry or public fallback" do
    options =
      opts(%{"eth_sendRawTransaction" => {:transport_error, :timeout}})
      |> Keyword.put(:private_rpc_url, "https://private.example")

    assert {:error, {:submission_unknown, %{transaction_hash: @hash, reason: {:transport, _}}}} =
             TransactionManager.submit("0x1234", options)

    assert_received {:rpc, "eth_sendRawTransaction", _, "private.example"}
    refute_received {:rpc, "eth_sendRawTransaction", _, _}
  end

  test "public submission is explicit and malformed hashes and bytes are rejected" do
    options = Keyword.put(opts(), :mev_protection, false)
    assert {:ok, @hash} = TransactionManager.submit("0x1234", options)
    assert_received {:rpc, "eth_sendRawTransaction", _, "public.example"}
    assert {:error, _} = TransactionManager.submit("0x", options)
    assert {:error, _} = TransactionManager.submit("0xz", options)

    bad_hash_opts =
      Keyword.put(opts(%{"eth_sendRawTransaction" => "0x1"}), :mev_protection, false)

    assert {:error, _} = TransactionManager.submit("0x1234", bad_hash_opts)
  end

  test "JSON-RPC response IDs are checked" do
    assert {:error, :invalid_rpc_response} =
             RPC.request("eth_chainId", [], opts(%{"eth_chainId" => :bad_id}))

    assert {:error, :rpc_url_required} = RPC.request("eth_chainId", [], [])
  end

  test "signer failures never submit" do
    assert {:error, :declined} =
             TransactionManager.execute(tx(), fn _ -> {:error, :declined} end, opts())

    refute_received {:rpc, "eth_sendRawTransaction", _, _}
  end

  test "execute supplies only a successful preflight to the signer" do
    options = Keyword.put(opts(), :private_rpc_url, "https://private.example")

    signer = fn unsigned ->
      assert unsigned["gas"] == Gas.hex(25_200)
      assert unsigned["nonce"] == "0x7"
      {:ok, "0x1234"}
    end

    assert {:ok, %{transaction_hash: @hash}} = TransactionManager.execute(tx(), signer, options)
  end

  test "batch encoding requires a sender-change acknowledgement and refuses value or lost fields" do
    call = %{"to" => @to, "data" => "0x1234"}
    assert {:error, _} = TransactionBatch.build([call], @batch)
    options = [allow_sender_change: true]
    assert {:ok, encoded} = TransactionBatch.build([call], @batch, options)
    assert encoded["to"] == @batch
    assert String.starts_with?(encoded["data"], "0x82ad56cb")

    for calls <- [
          [],
          [Map.put(call, "value", 1)],
          [Map.put(call, "from", @from)],
          [%{"to" => @to}],
          [nil]
        ] do
      assert {:error, _} = TransactionBatch.build(calls, @batch, options)
    end
  end

  test "batch planner chooses real savings and preserves call order in ABI calldata" do
    estimate = fn [tx, "pending"] ->
      if tx["to"] == @batch, do: Gas.hex(30_000), else: Gas.hex(21_000)
    end

    options = Keyword.put(opts(%{"eth_estimateGas" => estimate}), :allow_sender_change, true)
    calls = [%{"to" => @to, "data" => "0x1234"}, %{"to" => @from, "data" => "0xabcd"}]

    assert {:ok, %{strategy: :batch, gas_saved: 12_000, plans: [plan]}} =
             TransactionManager.plan_batch(calls, @from, @batch, options)

    <<_selector::binary-size(4), arguments::binary>> =
      Ethers.Utils.hex_decode!(plan.transaction["data"])

    [[{first, false, <<0x12, 0x34>>}, {second, false, <<0xAB, 0xCD>>}]] =
      ABI.decode("aggregate3((address,bool,bytes)[])", arguments)

    assert Ethers.Utils.hex_encode(first) == @to
    assert Ethers.Utils.hex_encode(second) == @from
  end

  test "uneconomical batches use consecutive individual nonces" do
    options = Keyword.put(opts(), :allow_sender_change, true)

    assert {:ok, %{strategy: :individual, plans: plans, gas_saved: 0}} =
             TransactionManager.plan_batch(
               [%{"to" => @to, "data" => "0x1234"}],
               @from,
               @batch,
               options
             )

    assert Enum.map(plans, & &1.transaction["nonce"]) == ["0x7"]
    estimate = fn [tx, _] -> if tx["to"] == @batch, do: Gas.hex(60_000), else: Gas.hex(21_000) end
    options = Keyword.put(opts(%{"eth_estimateGas" => estimate}), :allow_sender_change, true)

    assert {:ok, %{strategy: :individual, plans: plans}} =
             TransactionManager.plan_batch(
               List.duplicate(%{"to" => @to, "data" => "0x1234"}, 2),
               @from,
               @batch,
               options
             )

    assert Enum.map(plans, & &1.transaction["nonce"]) == ["0x7", "0x8"]
  end

  test "batching refuses missing contract code and a reverting batch" do
    call = %{"to" => @to, "data" => "0x1234"}
    options = Keyword.put(opts(%{"eth_getCode" => "0x"}), :allow_sender_change, true)

    assert {:error, :invalid_batch_sender_or_contract} =
             TransactionManager.plan_batch([call], @from, @batch, options)

    call_result = fn [tx, _] ->
      if tx["to"] == @batch, do: {:rpc_error, %{"code" => 3}}, else: "0x"
    end

    options = Keyword.put(opts(%{"eth_call" => call_result}), :allow_sender_change, true)
    assert {:error, {:rpc, _}} = TransactionManager.plan_batch([call], @from, @batch, options)
  end

  test "Lux prism dispatches quote and preflight through its real run interface" do
    assert {:ok, %{max_fee_per_gas: _}} = TransactionManagerPrism.run(%{action: "quote"}, opts())

    assert {:ok, %{simulation: _}} =
             TransactionManagerPrism.run(%{action: "prepare", transaction: tx()}, opts())

    assert {:error, _} = TransactionManagerPrism.run(%{action: "unknown"}, opts())
  end
end
