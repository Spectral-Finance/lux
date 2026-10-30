defmodule Lux.Rust.Component do
  @moduledoc """
  Framework support for defining native Lux Prisms and Beams in Rust.

  Provides traits, async/await bindings, and template generators for high-performance
  native components that interoperate directly with the Lux runtime.

  ## Examples

      iex> trait_code = Lux.Rust.Component.traits()
      iex> String.contains?(trait_code, "pub trait LuxPrism")
      true
  """

  @doc """
  Returns the canonical Rust trait definitions for Lux components.
  """
  def traits do
    """
    use async_trait::async_trait;
    use serde::{Serialize, Deserialize};
    use serde_json::Value;

    #[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
    pub enum ComponentState {
        Uninitialized,
        Ready,
        Running,
        Completed,
        Failed(String),
    }

    #[derive(Debug, Clone, Serialize, Deserialize)]
    pub struct ComponentMetadata {
        pub name: String,
        pub description: String,
        pub version: String,
        pub state: ComponentState,
    }

    #[async_trait]
    pub trait LuxPrism: Send + Sync {
        fn metadata(&self) -> ComponentMetadata;
        fn input_schema(&self) -> Value;
        async fn handler(&self, input: Value) -> Result<Value, String>;
    }

    #[async_trait]
    pub trait LuxBeam: Send + Sync {
        fn metadata(&self) -> ComponentMetadata;
        async fn run(&self, initial_state: Value) -> Result<Value, String>;
    }
    """
    |> String.trim()
  end

  @doc """
  Generates a full Rust Prism implementation from parameters.
  """
  def generate_prism(name, description, opts \\ []) do
    version = Keyword.get(opts, :version, "0.1.0")
    handler_code = Keyword.get(opts, :handler_code, "Ok(input)")

    """
    use async_trait::async_trait;
    use serde_json::{json, Value};
    use lux_core::{LuxPrism, ComponentMetadata, ComponentState};

    pub struct #{name};

    impl #{name} {
        pub fn new() -> Self {
            Self
        }
    }

    #[async_trait]
    impl LuxPrism for #{name} {
        fn metadata(&self) -> ComponentMetadata {
            ComponentMetadata {
                name: "#{name}".to_string(),
                description: "#{description}".to_string(),
                version: "#{version}".to_string(),
                state: ComponentState::Ready,
            }
        }

        fn input_schema(&self) -> Value {
            json!({
                "type": "object",
                "properties": {}
            })
        }

        async fn handler(&self, input: Value) -> Result<Value, String> {
            #{handler_code}
        }
    }
    """
    |> String.trim()
  end

  @doc """
  Generates a Rust Beam orchestrator implementation.
  """
  def generate_beam(name, description, opts \\ []) do
    version = Keyword.get(opts, :version, "0.1.0")

    """
    use async_trait::async_trait;
    use serde_json::Value;
    use lux_core::{LuxBeam, ComponentMetadata, ComponentState};

    pub struct #{name};

    impl #{name} {
        pub fn new() -> Self {
            Self
        }
    }

    #[async_trait]
    impl LuxBeam for #{name} {
        fn metadata(&self) -> ComponentMetadata {
            ComponentMetadata {
                name: "#{name}".to_string(),
                description: "#{description}".to_string(),
                version: "#{version}".to_string(),
                state: ComponentState::Ready,
            }
        }

        async fn run(&self, initial_state: Value) -> Result<Value, String> {
            Ok(initial_state)
        }
    }
    """
    |> String.trim()
  end
end
