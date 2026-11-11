# Perplexity AI Integration

`Lux.LLM.Perplexity` integrates Perplexity's Sonar model family (`sonar`, `sonar-pro`, `sonar-reasoning`, `sonar-reasoning-pro`, and `sonar-deep-research`) into Lux.

## Key Capabilities
- **Model Selection**: `Lux.LLM.Perplexity.select_model/2` selects the appropriate Sonar model based on task type and cost tier.
- **Grounded Citations & Search Filters**: Supports `search_domain_filter`, `search_recency_filter`, and automatic citation extraction.
- **SSE Streaming**: `parse_sse_stream/1` reassembles streamed delta chunks and deduplicates citations.
- **Cost Tracking**: `estimate_cost/4` tracks input tokens, output tokens, and search invocation fees.
