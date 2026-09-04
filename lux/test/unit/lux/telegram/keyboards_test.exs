defmodule Lux.Telegram.KeyboardsTest do
  use ExUnit.Case, async: true

  alias Lux.Telegram.Keyboards
  alias Lux.Telegram.Types.ForceReply
  alias Lux.Telegram.Types.InlineKeyboardButton
  alias Lux.Telegram.Types.InlineKeyboardMarkup
  alias Lux.Telegram.Types.KeyboardButton
  alias Lux.Telegram.Types.ReplyKeyboardMarkup
  alias Lux.Telegram.Types.ReplyKeyboardRemove

  describe "inline_button/2" do
    test "creates inline button with string callback_data" do
      btn = Keyboards.inline_button("Option A", "cb_a")
      assert %InlineKeyboardButton{text: "Option A", callback_data: "cb_a"} = btn
      assert Keyboards.to_map(btn) == %{text: "Option A", callback_data: "cb_a"}
    end

    test "creates inline button with options keyword list" do
      btn = Keyboards.inline_button("Open URL", url: "https://example.com")
      assert %InlineKeyboardButton{text: "Open URL", url: "https://example.com"} = btn
      assert Keyboards.to_map(btn) == %{text: "Open URL", url: "https://example.com"}
    end

    test "creates inline button with options map" do
      btn = Keyboards.inline_button("Search", %{switch_inline_query: "lux"})
      assert %InlineKeyboardButton{text: "Search", switch_inline_query: "lux"} = btn
      assert Keyboards.to_map(btn) == %{text: "Search", switch_inline_query: "lux"}
    end
  end

  describe "keyboard_button/2" do
    test "creates keyboard button with options" do
      btn = Keyboards.keyboard_button("Share Location", request_location: true)
      assert %KeyboardButton{text: "Share Location", request_location: true} = btn
      assert Keyboards.to_map(btn) == %{text: "Share Location", request_location: true}
    end
  end

  describe "inline_keyboard/1" do
    test "constructs inline keyboard structure from buttons, tuples, and maps" do
      b1 = Keyboards.inline_button("Yes", "yes")
      b2 = {"No", "no"}
      b3 = {"Info", [url: "https://example.com"]}
      b4 = %{text: "Custom", callback_data: "custom"}

      kb = Keyboards.inline_keyboard([[b1, b2], [b3, b4]])
      assert %InlineKeyboardMarkup{} = kb
      assert Keyboards.to_map(kb) == %{
               inline_keyboard: [
                 [%{text: "Yes", callback_data: "yes"}, %{text: "No", callback_data: "no"}],
                 [%{text: "Info", url: "https://example.com"}, %{text: "Custom", callback_data: "custom"}]
               ]
             }
    end
  end

  describe "reply_keyboard/2" do
    test "constructs reply keyboard from string rows, button structs, and scalars" do
      b_struct = %KeyboardButton{text: "Phone", request_contact: true}
      kb = Keyboards.reply_keyboard([["Option 1", b_struct], [:scalar_button]], resize_keyboard: true, one_time_keyboard: true)

      assert %ReplyKeyboardMarkup{resize_keyboard: true, one_time_keyboard: true} = kb
      assert Keyboards.to_map(kb) == %{
               keyboard: [
                 [%{text: "Option 1"}, %{text: "Phone", request_contact: true}],
                 [%{text: "scalar_button"}]
               ],
               resize_keyboard: true,
               one_time_keyboard: true
             }
    end

    test "constructs reply keyboard preserving button maps" do
      kb = Keyboards.reply_keyboard([[%{text: "Contact", request_contact: true}]])
      assert %ReplyKeyboardMarkup{} = kb
      assert Keyboards.to_map(kb) == %{keyboard: [[%{text: "Contact", request_contact: true}]]}
    end
  end

  describe "remove_reply_keyboard/1 and reply_keyboard_remove/1" do
    test "constructs remove reply keyboard markup" do
      kb = Keyboards.remove_reply_keyboard(selective: true)
      assert %ReplyKeyboardRemove{remove_keyboard: true, selective: true} = kb
      assert Keyboards.to_map(kb) == %{remove_keyboard: true, selective: true}

      kb2 = Keyboards.reply_keyboard_remove(%{selective: false})
      assert %ReplyKeyboardRemove{remove_keyboard: true, selective: false} = kb2
    end
  end

  describe "force_reply/1" do
    test "force_reply constructs force reply markup" do
      kb = Keyboards.force_reply(input_field_placeholder: "Enter reply...", selective: true)
      assert %ForceReply{force_reply: true, input_field_placeholder: "Enter reply...", selective: true} = kb
      assert Keyboards.to_map(kb) == %{
               force_reply: true,
               input_field_placeholder: "Enter reply...",
               selective: true
             }
    end

    test "inline_keyboard with scalar passthrough" do
      res = Keyboards.inline_keyboard([["scalar_btn"]])
      assert %Lux.Telegram.Types.InlineKeyboardMarkup{inline_keyboard: [["scalar_btn"]]} = res
    end
  end
end

