## Ollama Integration

Lux now supports local model execution via Ollama, allowing you to run models on your own infrastructure with optimized performance. This provides greater control over resource usage, data privacy, and model management.

### Key Features
- Ollama API client integration
- Local model management
- Model caching and versioning
- Resource usage controls
- Performance monitoring

### Getting Started

To use Ollama with Lux, first install the Ollama CLI and start a local server:

```bash
ollama serve
```

Then, register your models in Lux:

```elixir
Lux.ModelManager.register_model(:my_model, config: [model: :llama2, temperature: 0.7])
```

You can then call your model like any other Lux component:

```elixir
Lux.LLM.call(:my_model, input: "Hello, world!")
```

### Model Management

Lux provides a comprehensive model management system with:
- Model registration and unregistration
- Configuration management
- Caching for frequently used models
- Resource usage tracking

### Performance Monitoring

Lux includes performance monitoring capabilities to help you optimize model execution:
- Latency tracking
- Throughput measurement
- Resource usage metrics
- Automatic scaling recommendations

For more information, see the [Ollama Integration Guide](lux/guides/ollama_integration.md).