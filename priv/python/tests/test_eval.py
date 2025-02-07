"""Tests for the eval module."""
import pytest
from lux.atoms import Atom

from lux.eval import encode_term, decode_term, execute

def test_encode_basic_types():
    """Test encoding of basic Python types to Erlang terms."""
    assert encode_term(None) == Atom(b'nil')
    assert encode_term(True) is True
    assert encode_term(False) is False
    assert encode_term(42) == 42
    assert encode_term(3.14) == 3.14
    assert encode_term("hello") == b"hello"

def test_encode_collections():
    """Test encoding of Python collections."""
    # Lists
    assert encode_term([1, 2, 3]) == [1, 2, 3]
    assert encode_term(["a", "b"]) == [b"a", b"b"]
    
    # Tuples (converted to lists)
    assert encode_term((1, 2)) == [1, 2]
    
    # Dictionaries
    assert encode_term({"a": 1, "b": 2}) == {b"a": 1, b"b": 2}
    
    # Nested collections
    assert encode_term({
        "list": [1, 2],
        "map": {"x": 10}
    }) == {
        b"list": [1, 2],
        b"map": {b"x": 10}
    }

def test_encode_struct_conversion():
    """Test conversion of Python dicts to Elixir structs."""
    # Basic struct
    result = encode_term({
        "__class__": "user",
        "name": "Alice",
        "role": "admin"
    })
    assert isinstance(result, dict)
    assert result[Atom(b"__struct__")] == Atom(b"Elixir.User")
    assert result[Atom(b"name")] == b"Alice"
    assert result[Atom(b"role")] == b"admin"
    
    # Nested module name
    result = encode_term({
        "__class__": "data.types.point",
        "x": 1,
        "y": 2
    })
    assert result[Atom(b"__struct__")] == Atom(b"Elixir.Data.Types.Point")
    assert result[Atom(b"x")] == 1
    assert result[Atom(b"y")] == 2

def test_decode_basic_types():
    """Test decoding of Erlang terms to Python types."""
    assert decode_term(Atom(b"nil")) == "nil"
    assert decode_term(True) is True
    assert decode_term(False) is False
    assert decode_term(42) == 42
    assert decode_term(3.14) == 3.14
    assert decode_term(b"hello") == "hello"

def test_decode_collections():
    """Test decoding of Erlang collections."""
    assert decode_term([1, 2, 3]) == [1, 2, 3]
    assert decode_term([b"a", b"b"]) == ["a", "b"]
    assert decode_term({b"a": 1, b"b": 2}) == {"a": 1, "b": 2}

def test_execute_basic():
    """Test basic Python code execution."""
    assert execute("1 + 1") == 2
    assert execute("'hello' + ' world'") == b"hello world"
    assert execute("[1, 2, 3]") == [1, 2, 3]

def test_execute_with_variables():
    """Test execution with variable bindings."""
    variables = {b"x": 5, b"y": 6}
    assert execute("x * y", variables) == 30
    
    variables = {
        b"data": {
            b"numbers": [1, 2, 3],
            b"name": b"test"
        }
    }
    assert execute("data['numbers'][1]", variables) == 2
    assert execute("data['name']", variables) == b"test"

def test_execute_multiline():
    """Test execution of multi-line Python code."""
    code = """
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)
factorial(5)
"""
    assert execute(code) == 120

def test_execute_error_handling():
    """Test error handling in code execution."""
    with pytest.raises(RuntimeError) as exc_info:
        execute("undefined_variable")
    assert "NameError: name 'undefined_variable' is not defined" in str(exc_info.value)

    with pytest.raises(RuntimeError) as exc_info:
        execute("1/0")
    assert "ZeroDivisionError: division by zero" in str(exc_info.value)