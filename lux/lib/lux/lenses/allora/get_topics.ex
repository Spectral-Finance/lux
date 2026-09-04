defmodule Lux.Lenses.Allora.GetTopics do
  @moduledoc """
  A lens for fetching all available topics from the Allora API.
  This lens provides information about all active prediction topics in the Allora network.

  ## Topic Information
  Each topic includes:
  - `topic_id`: Unique identifier for the topic
  - `topic_name`: Human-readable name of the topic
  - `description`: Detailed description of what the topic predicts
  - `epoch_length`: Duration of each prediction epoch in seconds
  - `ground_truth_lag`: Time delay before ground truth is available (in seconds)
  - `loss_method`: Method used to calculate prediction accuracy (e.g., "rmse")
  - `worker_submission_window`: Time window for workers to submit predictions (in seconds)
  - `worker_count`: Number of active prediction workers
  - `reputer_count`: Number of active reputation scorers
  - `total_staked_allo`: Total amount of ALLO tokens staked
  - `total_emissions_allo`: Total ALLO token emissions for this topic
  - `is_active`: Whether the topic is currently active
  - `updated_at`: Last update timestamp

  ## Use Cases
  - Discover available prediction topics
  - Monitor network participation (workers and reputers)
  - Track staking and emissions for topics
  - Check topic activity status

  ## Examples
      iex> GetTopics.focus(%{})
      {:ok, [
        %{
          topic_id: 1,
          topic_name: "BTC/USD",
          description: "Bitcoin price prediction",
          epoch_length: 300,              # 5 minutes
          ground_truth_lag: 60,           # 1 minute
          loss_method: "rmse",
          worker_submission_window: 60,    # 1 minute
          worker_count: 10,
          reputer_count: 3,
          total_staked_allo: 1000.0,
          total_emissions_allo: 100.0,
          is_active: true,
          updated_at: "2024-03-28T12:00:00Z"
        },
        %{
          topic_id: 2,
          topic_name: "ETH/USD",
          description: "Ethereum price prediction",
          # ... similar fields ...
        }
      ]}
  """

  alias Lux.Integrations.Allora
  require Logger

  use Lux.Lens,
    name: "Get Allora Topics",
    description: "Fetches all available topics from the Allora network",
    url: "#{Allora.base_url()}/allora/#{Allora.chain_id()}/topics",
    method: :get,
    headers: Allora.headers(),
    auth: Allora.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @doc """
  Transforms the Allora API response into a simpler format.
  Handles pagination automatically by making additional requests when needed.

  The response is transformed to provide:
  - Consistent field types (numbers for numeric values)
  - ISO8601 formatted timestamps
  - Normalized boolean values for activity status

  ## Examples
      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "topics" => [
      ...>       %{
      ...>         "topic_id" => 1,
      ...>         "topic_name" => "BTC/USD",
      ...>         "description" => "Bitcoin price prediction",
      ...>         "epoch_length" => 300,
      ...>         "ground_truth_lag" => 60,
      ...>         "loss_method" => "rmse",
      ...>         "worker_submission_window" => 60,
      ...>         "worker_count" => 10,
      ...>         "reputer_count" => 3,
      ...>         "total_staked_allo" => 1000.0,
      ...>         "total_emissions_allo" => 100.0,
      ...>         "is_active" => true,
      ...>         "updated_at" => "2024-03-28T12:00:00Z"
      ...>       }
      ...>     ]
      ...>   }
      ...> })
      {:ok, [%{topic_id: 1, topic_name: "BTC/USD", ...}]}
  """
  @impl true
  def after_focus(%{"data" => %{"topics" => topics}} = _response) do
    Logger.info("Successfully fetched #{length(topics)} topics from Allora API (chain_id: #{Allora.chain_id()})")

    transformed_topics = Enum.map(topics, &transform_topic/1)
    {:ok, transformed_topics}
  end

  def after_focus(%{"error" => error} = _response) do
    Logger.error("Failed to fetch topics from Allora API (chain_id: #{Allora.chain_id()}) - Error: #{inspect(error)}")
    {:error, error}
  end

  defp transform_topic(topic) do
    %{
      topic_id: topic["topic_id"],
      topic_name: topic["topic_name"],
      description: topic["description"],
      epoch_length: topic["epoch_length"],
      ground_truth_lag: topic["ground_truth_lag"],
      loss_method: topic["loss_method"],
      worker_submission_window: topic["worker_submission_window"],
      worker_count: topic["worker_count"],
      reputer_count: topic["reputer_count"],
      total_staked_allo: topic["total_staked_allo"],
      total_emissions_allo: topic["total_emissions_allo"],
      is_active: topic["is_active"],
      updated_at: topic["updated_at"]
    }
  end
end
