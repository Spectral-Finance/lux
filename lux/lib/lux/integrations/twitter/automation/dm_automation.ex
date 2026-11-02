defmodule Lux.Integrations.Twitter.Automation.DMAutomation do
  @moduledoc """
  Automates Direct Message (DM) interactions, welcome messages for new followers,
  keyword-driven auto-responses, and opt-out preferences.
  """

  @opt_out_keywords ["stop", "unsubscribe", "opt out", "cancel", "halt"]

  @default_welcome_template "Hey @%{username}, thanks for following Lux! Feel free to ask any questions or check out https://docs.lux.xyz"

  @faq_rules %{
    "docs" => "You can view our technical architecture and documentation at https://docs.lux.xyz",
    "partnership" => "For partnership inquiries, please contact our team at partners@spectral.finance",
    "support" => "Need help? Join our community Discord or describe your issue here and an agent will assist you."
  }

  @doc """
  Generates a personalized welcome DM for a new follower.
  """
  @spec generate_welcome_message(map(), String.t()) :: String.t()
  def generate_welcome_message(user, template \\ @default_welcome_template) do
    username = Map.get(user, :username) || Map.get(user, "username") || "friend"
    String.replace(template, "%{username}", username)
  end

  @doc """
  Processes an incoming Direct Message. Checks for opt-out requests,
  evaluates keyword auto-responses, and updates user session state.
  """
  @spec process_message(map(), MapSet.t()) :: {:ok, map(), MapSet.t()}
  def process_message(dm, opted_out_users) do
    sender_id = to_string(Map.get(dm, :sender_id) || Map.get(dm, "sender_id"))
    text = String.trim(Map.get(dm, :text) || Map.get(dm, "text") || "")
    lower = String.downcase(text)

    cond do
      MapSet.member?(opted_out_users, sender_id) ->
        {:ok, %{action: :ignore, reason: :user_opted_out}, opted_out_users}

      is_opt_out_command?(lower) ->
        new_set = MapSet.put(opted_out_users, sender_id)

        {:ok,
         %{
           action: :reply,
           reply_text: "You have been successfully opted out of automated messages.",
           reason: :opt_out_confirmed
         }, new_set}

      match = find_faq_response(lower) ->
        {:ok, %{action: :reply, reply_text: match, reason: :faq_match}, opted_out_users}

      true ->
        {:ok,
         %{
           action: :route_to_agent,
           reply_text: "Thanks for your message! Our team will get back to you shortly.",
           reason: :unmatched_query
         }, opted_out_users}
    end
  end

  @doc """
  Checks if a message text is an opt-out command.
  """
  @spec is_opt_out_command?(String.t()) :: boolean()
  def is_opt_out_command?(text) when is_binary(text) do
    lower = String.downcase(String.trim(text))
    lower in @opt_out_keywords
  end

  defp find_faq_response(text) do
    Enum.find_value(@faq_rules, fn {keyword, reply} ->
      if String.contains?(text, keyword), do: reply, else: nil
    end)
  end
end
