defmodule Lux.Community.YouTube.ResponseGeneratorTest do
  use ExUnit.Case, async: true

  alias Lux.Community.YouTube.ResponseGenerator

  describe "generate_response/3" do
    test "generates personalized praise acknowledgement" do
      response = ResponseGenerator.generate_response("Incredible work, best tutorial on YouTube!", "DevFan")
      assert String.contains?(response.reply_text, "@DevFan")
      assert response.intent_detected == :praise
    end

    test "generates helpful answer guidance for inquiries" do
      response = ResponseGenerator.generate_response("Where can I find the GitHub repository for this?", "Student")
      assert response.intent_detected == :inquiry
      assert String.length(response.reply_text) > 20
    end
  end

  describe "generate_options/2" do
    test "provides multiple creator reply suggestions" do
      options = ResponseGenerator.generate_options("Love the content!", "Alice")
      assert length(options) > 1
      assert Enum.all?(options, &String.contains?(&1, "@Alice"))
    end
  end
end
