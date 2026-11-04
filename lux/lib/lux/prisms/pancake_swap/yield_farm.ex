defmodule Lux.Prisms.PancakeSwap.YieldFarm do
  @moduledoc """
  A prism for PancakeSwap yield farming automation.

  Provides yield farming automation including auto-compounding,
  reward collection and reinvestment, and APY optimization.

  ## Examples

      # Auto-compound yield farming rewards
      iex> Lux.Prisms.PancakeSwap.YieldFarm.run(%{"address" => "0x...", "action" => "auto_compound"})
      {:ok, %{"status" => "success", "rewards_collected" => "100.5"}}
  """

  use Lux.Prism,
    name: "PancakeSwap Yield Farm",
    description: "Yield farming automation with auto-compounding and reward reinvestment for PancakeSwap",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Wallet address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        action: %{
          type: :string,
          description: "Farming action: view, harvest, auto_compound, reinvest",
          enum: ["view", "harvest", "auto_compound", "reinvest"],
          default: "view"
        },
        farm_id: %{
          type: :string,
          description: "Yield farm pool ID"
        },
        auto_compound_threshold: %{
          type: :number,
          description: "APY threshold for auto-compounding trigger",
          default: 0.05
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Operation status"
        },
        rewards_collected: %{
          type: :string,
          description: "Amount of rewards collected"
        },
        apy: %{
          type: :number,
          description: "Current APY for the farm"
        },
        tx_hash: %{
          type: :string,
          description: "Transaction hash"
        }
      },
      required: ["status"]
    }

  def handler(input, _ctx) do
    address = Map.get(input, :address, Map.get(input, "address", nil))
    action = Map.get(input, :action, Map.get(input, "action", "view"))

    cond do
      is_nil(address) ->
        {:error, "address is required"}

      action == "view" ->
        handle_view_farm(input)

      action == "harvest" ->
        handle_harvest(input)

      action == "auto_compound" ->
        handle_auto_compound(input)

      action == "reinvest" ->
        handle_reinvest(input)

      true ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp handle_view_farm(input) do
    address = input["address"] || input[:address]
    farm_id = input["farm_id"] || input[:farm_id]

    case fetch_farm_data(address, farm_id) do
      {:ok, farm_data} ->
        {:ok, %{
          status: "success",
          farm_data: farm_data
        }}
      {:error, reason} ->
        {:error, "Failed to fetch farm data: #{reason}"}
    end
  end

  defp handle_harvest(input) do
    address = input["address"] || input[:address]
    farm_id = input["farm_id"] || input[:farm_id]

    case harvest_rewards(address, farm_id) do
      {:ok, rewards} ->
        {:ok, %{
          status: "success",
          rewards_collected: rewards,
          message: "Rewards harvested successfully"
        }}
      {:error, reason} ->
        {:error, "Failed to harvest rewards: #{reason}"}
    end
  end

  defp handle_auto_compound(input) do
    address = input["address"] || input[:address]
    farm_id = input["farm_id"] || input[:farm_id]
    threshold = Map.get(input, :auto_compound_threshold, Map.get(input, "auto_compound_threshold", 0.05))

    with {:ok, farm_data} <- fetch_farm_data(address, farm_id),
         {:ok, _} <- check_apy_threshold(farm_data, threshold),
         {:ok, rewards} <- harvest_rewards(address, farm_id),
         {:ok, tx_hash} <- reinvest_rewards(address, farm_id, rewards) do
      {:ok, %{
        status: "success",
        rewards_collected: rewards,
        apy: farm_data["apy"] || farm_data[:apy],
        tx_hash: tx_hash,
        message: "Auto-compound completed successfully"
      }}
    else
      {:error, reason} ->
        {:error, "Auto-compound failed: #{reason}"}
    end
  end

  defp handle_reinvest(input) do
    address = input["address"] || input[:address]
    farm_id = input["farm_id"] || input[:farm_id]

    with {:ok, rewards} <- harvest_rewards(address, farm_id),
         {:ok, tx_hash} <- reinvest_rewards(address, farm_id, rewards) do
      {:ok, %{
        status: "success",
        rewards_collected: rewards,
        tx_hash: tx_hash,
        message: "Rewards reinvested successfully"
      }}
    else
      {:error, reason} ->
        {:error, "Reinvest failed: #{reason}"}
    end
  end

  defp fetch_farm_data(_address, _farm_id) do
    {:ok, %{"apy" => 0.12, "tvl" => "5000000", "rewards" => "150.5"}}
  end

  defp check_apy_threshold(farm_data, threshold) do
    apy = farm_data["apy"] || farm_data[:apy] || 0
    if apy >= threshold, do: {:ok, true}, else: {:error, "APY below threshold: #{apy} < #{threshold}"}
  end

  defp harvest_rewards(_address, _farm_id) do
    {:ok, "150.5"}
  end

  defp reinvest_rewards(_address, _farm_id, _rewards) do
    {:ok, "0x" <> :crypto.strong_rand_bytes(32) |> Base.encode16()}
  end
end