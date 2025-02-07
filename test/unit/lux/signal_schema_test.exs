defmodule Lux.SignalSchemaTest do
  use UnitCase, async: true

  alias Lux.SignalSchema

  describe "new/1" do
    test "creates a schema from a map" do
      attrs = %{
        name: "test_schema",
        description: "Test schema",
        version: "1.0.0",
        schema: %{type: :object, properties: %{name: %{type: :string}}}
      }

      schema = SignalSchema.new(attrs)

      assert %SignalSchema{} = schema
      assert schema.name == "test_schema"
      assert schema.description == "Test schema"
      assert schema.version == "1.0.0"
      assert schema.schema == %{type: :object, properties: %{name: %{type: :string}}}
    end
  end

  describe "when using SignalSchema" do
    test "creates a schema with declarative attributes" do
      defmodule ChatMessageSchema do
        @moduledoc false
        use Lux.SignalSchema,
          name: "chat_message",
          description: "Basic chat message schema",
          version: "1.0.0",
          schema: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              from: %{type: :string},
              to: %{type: :string}
            },
            required: ["message", "from", "to"]
          },
          tags: ["chat", "communication"],
          compatibility: :full,
          format: :json
      end

      schema_definition = ChatMessageSchema.view()
      schema = schema_definition.schema

      assert %{
               "type" => "object",
               "properties" => %{
                 "message" => %{"type" => "string"},
                 "from" => %{"type" => "string"},
                 "to" => %{"type" => "string"}
               },
               "required" => ["message", "from", "to"]
             } = schema

      assert schema_definition.name == "chat_message"
      assert schema_definition.description == "Basic chat message schema"
      assert schema_definition.version == "1.0.0"
      assert schema_definition.tags == ["chat", "communication"]
      assert schema_definition.compatibility == :full
      assert schema_definition.format == :json
    end

    test "uses module name as default name" do
      defmodule DefaultNameSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :object, properties: %{message: %{type: :string}}, required: []}
      end

      schema = DefaultNameSchema.view()
      assert schema.name == "DefaultNameSchema"
      assert schema.id == DefaultNameSchema.schema_id()

      assert schema.schema == %{
               "type" => "object",
               "properties" => %{"message" => %{"type" => "string"}},
               "required" => []
             }

      assert schema.description == nil
      assert schema.version == nil
      assert schema.tags == []
      assert schema.compatibility == :full
      assert schema.format == :json
    end

    test "provides schema_id helper" do
      defmodule SchemaWithId do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :object}
      end

      assert is_binary(SchemaWithId.schema_id())
      assert SchemaWithId.schema_id() == SchemaWithId.view().id
    end
  end

  describe "SignalSchema validation" do
    test "null" do
      defmodule NullSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :null}
      end

      assert {:ok, %Lux.Signal{payload: nil}} = NullSchema.validate(%Lux.Signal{payload: nil})
      assert {:error, _} = NullSchema.validate(%Lux.Signal{payload: 1})
    end

    test "boolean" do
      defmodule BooleanSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :boolean}
      end

      assert {:ok, %Lux.Signal{payload: true}} =
               BooleanSchema.validate(%Lux.Signal{payload: true})

      assert {:ok, %Lux.Signal{payload: false}} =
               BooleanSchema.validate(%Lux.Signal{payload: false})

      assert {:error, _} = BooleanSchema.validate(%Lux.Signal{payload: "true"})
      assert {:error, _} = BooleanSchema.validate(%Lux.Signal{payload: "false"})
      assert {:error, _} = BooleanSchema.validate(%Lux.Signal{payload: 1})
    end

    test "integer" do
      defmodule IntegerSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :integer}
      end

      expected_signal = %Lux.Signal{payload: 1}
      invalid_signal = %Lux.Signal{payload: "1"}

      assert {:ok, ^expected_signal} = IntegerSchema.validate(expected_signal)
      assert {:error, _} = IntegerSchema.validate(invalid_signal)
    end

    test "string" do
      defmodule StringSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :string}
      end

      expected_signal = %Lux.Signal{payload: "test"}
      invalid_signal = %Lux.Signal{payload: 1}

      assert {:ok, ^expected_signal} = StringSchema.validate(expected_signal)
      assert {:error, _} = StringSchema.validate(invalid_signal)
    end

    test "array" do
      defmodule ArraySchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :array, items: %{type: :string}}
      end

      expected_signal = %Lux.Signal{payload: ["test", "test2"]}
      expected_signal_2 = %Lux.Signal{payload: []}

      assert {:ok, ^expected_signal} = ArraySchema.validate(expected_signal)
      assert {:ok, ^expected_signal_2} = ArraySchema.validate(expected_signal_2)
      # invalid signals
      assert {:error, _} = ArraySchema.validate(%Lux.Signal{payload: ["test", 1]})
      assert {:error, _} = ArraySchema.validate(%Lux.Signal{payload: ["test", "test2", nil]})
      assert {:error, _} = ArraySchema.validate(%Lux.Signal{payload: [nil]})
    end

    test "object" do
      defmodule ObjectSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              index: %{type: :integer},
              meta: %{
                type: :object,
                properties: %{
                  foo: %{type: :string},
                  bar: %{type: :array, items: %{type: :string}}
                },
                required: ["foo"]
              }
            },
            required: ["message"]
          }
      end

      expected_signal = %Lux.Signal{payload: %{message: "test", index: 1, meta: %{foo: "bar"}}}
      expected_signal_2 = %Lux.Signal{payload: %{message: "test", index: 1}}

      assert {:ok, ^expected_signal} = ObjectSchema.validate(expected_signal)
      assert {:ok, ^expected_signal_2} = ObjectSchema.validate(expected_signal_2)
      # missing required fields
      assert {:error, [{"Required property message was not present.", _}]} =
               ObjectSchema.validate(%Lux.Signal{payload: %{index: 1}})

      assert {:error, [{"Required property foo was not present.", "#/meta"}]} =
               ObjectSchema.validate(%Lux.Signal{
                 payload: %{message: "test", index: 1, meta: %{bar: ["foo"]}}
               })
    end

    test "validates enums" do
      defmodule EnumSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :string, enum: ["foo", "bar", "baz"]}
      end

      valid_signal = %Lux.Signal{payload: "foo"}
      valid_signal_2 = %Lux.Signal{payload: "bar"}

      assert {:ok, ^valid_signal} = EnumSchema.validate(valid_signal)
      assert {:ok, ^valid_signal_2} = EnumSchema.validate(valid_signal_2)

      assert {:error, _} = EnumSchema.validate(%Lux.Signal{payload: "invalid"})
      assert {:error, _} = EnumSchema.validate(%Lux.Signal{payload: "FOO"})
    end
  end

  describe "format validation" do
    test "validates date-time format" do
      defmodule DateTimeSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :string, format: "date-time"}
      end

      valid_signal = %Lux.Signal{payload: "2024-03-21T17:32:28Z"}

      invalid_signals = [
        # Missing time
        %Lux.Signal{payload: "2024-03-21"},
        # Missing date
        %Lux.Signal{payload: "17:32:28Z"},
        # Invalid format
        %Lux.Signal{payload: "not a date"},
        # Invalid month
        %Lux.Signal{payload: "2024-13-21T17:32:28Z"}
      ]

      assert {:ok, ^valid_signal} = DateTimeSchema.validate(valid_signal)

      for invalid_signal <- invalid_signals do
        assert {:error, _} = DateTimeSchema.validate(invalid_signal)
      end
    end

    test "validates email format" do
      defmodule EmailSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :string, format: "email"}
      end

      valid_signal = %Lux.Signal{payload: "user@example.com"}

      invalid_signals = [
        %Lux.Signal{payload: "not-an-email"},
        %Lux.Signal{payload: "@example.com"},
        %Lux.Signal{payload: "user@"},
        %Lux.Signal{payload: "user@.com"},
        %Lux.Signal{payload: "user@example."}
      ]

      assert {:ok, ^valid_signal} = EmailSchema.validate(valid_signal)

      for invalid_signal <- invalid_signals do
        assert {:error, _} = EmailSchema.validate(invalid_signal)
      end
    end

    test "validates hostname format" do
      defmodule HostnameSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{type: :string, format: "hostname"}
      end

      valid_signal = %Lux.Signal{payload: "example.com"}

      invalid_signals = [
        %Lux.Signal{payload: "not a hostname!"},
        %Lux.Signal{payload: "-invalid.com"},
        %Lux.Signal{payload: "example-.com"},
        %Lux.Signal{payload: "example..com"}
      ]

      assert {:ok, ^valid_signal} = HostnameSchema.validate(valid_signal)

      for invalid_signal <- invalid_signals do
        assert {:error, _} = HostnameSchema.validate(invalid_signal)
      end
    end

    test "validates IP address formats" do
      defmodule IpSchema do
        @moduledoc false
        use Lux.SignalSchema,
          schema: %{
            type: :object,
            properties: %{
              ipv4: %{type: :string, format: "ipv4"},
              ipv6: %{type: :string, format: "ipv6"}
            }
          }
      end

      valid_signal = %Lux.Signal{
        payload: %{
          ipv4: "192.168.1.1",
          ipv6: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        }
      }

      invalid_signals = [
        %Lux.Signal{
          payload: %{ipv4: "256.1.2.3", ipv6: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"}
        },
        %Lux.Signal{payload: %{ipv4: "1.2.3", ipv6: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"}},
        %Lux.Signal{payload: %{ipv4: "192.168.1.1", ipv6: "not-an-ipv6"}},
        %Lux.Signal{
          payload: %{ipv4: "192.168.1.1", ipv6: "2001:0db8:85a3:0000:0000:8a2e:0370:xxxx"}
        }
      ]

      assert {:ok, ^valid_signal} = IpSchema.validate(valid_signal)

      for invalid_signal <- invalid_signals do
        assert {:error, _} = IpSchema.validate(invalid_signal)
      end
    end
  end
end
