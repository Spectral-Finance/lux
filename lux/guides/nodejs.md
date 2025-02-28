# Node.js Integration in Lux

Lux provides robust support for Node.js, allowing you to leverage the vast JavaScript ecosystem in your agents. This guide explains how to use Node.js effectively with Lux.

## Writing JavaScript Code

### Using the ~JS Sigil

The `~JS` sigil allows you to write JavaScript code directly in your Elixir files:

```elixir
defmodule MyApp.Prisms.TextProcessingPrism do
  use Lux.Prism,
    name: "Text Processing"

  require Lux.NodeJS
  import Lux.NodeJS

  def handler(input, _ctx) do
    result = nodejs variables: %{text: input} do
      ~JS"""
      import { tokenize } from 'natural';
      import { sentiment } from 'sentiment';
      
      // Process input text
      const tokens = tokenize(text);
      const analysis = sentiment(text);
      
      export const main = () => ({
        tokens,
        sentiment: analysis.score,
        comparative: analysis.comparative
      });
      """
    end

    {:ok, result}
  end
end
```

Key features:
- Modern JavaScript (ES modules) support
- Variable binding between Elixir and JavaScript
- Automatic type conversion
- Error handling and timeouts
- Full async/await support

### Custom JavaScript Modules

You can add your own JavaScript modules under the `priv/node` directory:

```
priv/node/
├── src/
│   ├── analysis.mjs
│   └── utils.mjs
├── package.json
└── package-lock.json
```

These modules can be imported and used in your Lux code:

```elixir
nodejs do
  ~JS"""
  import { analyzeText } from './src/analysis.mjs';
  import { formatOutput } from './src/utils.mjs';
  
  const result = await analyzeText(input);
  export const main = () => formatOutput(result);
  """
end
```

## Package Management

### Using NPM

Lux uses NPM for JavaScript package management. The `package.json` file in `priv/node` defines your dependencies:

```json
{
  "name": "lux-nodejs",
  "version": "0.1.0",
  "description": "Node.js support for Lux framework",
  "type": "module",
  "dependencies": {
    "natural": "^6.0.0",
    "sentiment": "^5.0.0",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0"
  }
}
```

To install dependencies:

```bash
cd priv/node
npm install
```

### Importing Packages

Use `Lux.NodeJS.import_package/1` to dynamically import Node.js packages:

```elixir
# Import a single package
{:ok, %{"success" => true}} = Lux.NodeJS.import_package("lodash")

# Import multiple packages
for package <- ["natural", "sentiment", "axios"] do
  {:ok, %{"success" => true}} = Lux.NodeJS.import_package(package)
end
```

## Type Conversion

Lux automatically handles type conversion between Elixir and JavaScript:

| Elixir Type | JavaScript Type |
|-------------|----------------|
| `nil` | `null` |
| `true`/`false` | `true`/`false` |
| Integer | `number` |
| Float | `number` |
| String | `string` |
| List | `Array` |
| Map | `Object` |
| Struct | JavaScript class |

Example:

```elixir
nodejs variables: %{
  number: 42,
  text: "hello",
  list: [1, 2, 3],
  map: %{key: "value"}
} do
  ~JS"""
  // number is a number
  // text is a string
  // list is an Array
  // map is an Object
  
  export const main = () => ({
    numberType: typeof number,
    textType: typeof text,
    listType: Array.isArray(list),
    mapType: typeof map
  });
  """
end
```

## Async/Await Support

Lux fully supports JavaScript's async/await:

```elixir
nodejs do
  ~JS"""
  import axios from 'axios';
  
  // Async operations are supported
  const response = await axios.get('https://api.example.com/data');
  
  export const main = () => ({
    status: response.status,
    data: response.data
  });
  """
end
```

## Error Handling

JavaScript errors are properly captured and converted to Elixir errors:

```elixir
# Handle errors with pattern matching
case nodejs do
  ~JS"""
  // This will throw a ReferenceError
  undefinedVariable;
  """
end do
  {:ok, result} -> handle_success(result)
  {:error, error} -> handle_error(error)
end

# Or use the bang version to raise errors
nodejs! do
  ~JS"""
  // This will throw an Error
  throw new Error("Something went wrong");
  """
end
```

## Testing

Test your JavaScript code using the standard Elixir testing tools:

```elixir
defmodule MyApp.Prisms.TextProcessingPrismTest do
  use UnitCase, async: true
  
  import Lux.NodeJS
  
  test "processes text correctly" do
    result = nodejs variables: %{text: "Hello, world!"} do
      ~JS"""
      import { tokenize } from 'natural';
      export const main = () => tokenize(text);
      """
    end
    
    assert {:ok, ["Hello", "world"]} = result
  end
  
  test "handles errors" do
    assert {:error, error} = nodejs do
      ~JS"""
      undefinedVariable;
      """
    end
    
    assert error =~ "ReferenceError"
  end
end
```

## Best Practices

1. **Module Organization**
   - Keep related JavaScript code in modules under `priv/node/src`
   - Use ES modules for better code organization
   - Follow JavaScript style guidelines

2. **Performance**
   - Use async/await for I/O operations
   - Batch operations to minimize cross-language calls
   - Consider memory usage with large datasets

3. **Error Handling**
   - Use appropriate error types
   - Provide meaningful error messages
   - Clean up resources in error cases

4. **Testing**
   - Test both success and error cases
   - Verify type conversions
   - Test with realistic data

## Coming Soon

Lux will soon support defining components entirely in JavaScript:

```javascript
import { Prism, Beam, Agent } from 'lux';

class MyPrism extends Prism {
  name = "JavaScript Prism";
  description = "A prism implemented in JavaScript";
  
  async handler(input, context) {
    // Process input
    const result = await this.processData(input);
    return { success: true, data: result };
  }
}
```

This will allow you to:
- Write agents entirely in JavaScript
- Define prisms and beams in JavaScript
- Use JavaScript's class system
- Leverage Node.js's async capabilities

Stay tuned for updates! 