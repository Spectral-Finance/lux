defmodule Lux.Integrations.Twitter.ContentManagerTest do
  use ExUnit.Case
  alias Lux.Integrations.Twitter.ContentManager

  setup do
    start_supervised!(ContentManager)
    :ok
  end

  test "adds and retrieves content" do
    ContentManager.add_content("Tweet 1")
    ContentManager.add_content("Tweet 2")

    assert length(ContentManager.list_all()) == 2
    assert ContentManager.get_random() in ["Tweet 1", "Tweet 2"]
  end

  test "returns nil when empty" do
    assert ContentManager.get_random() == nil
  end
end
