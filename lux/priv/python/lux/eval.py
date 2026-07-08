"""
Python code evaluation module for Lux. Access via `:lux.eval`

This module provides functionality to evaluate Python code and convert Python values to Elixir terms.
Special handling is provided for converting Python dictionaries to Elixir structs when they contain
a '__class__' key.

Struct Conversion:
    Python dictionaries with a '__class__' key are converted to Elixir structs. For example:
    {'__class__': 'user', 'name': 'Alice'} -> %User{name: "Alice"}

    The conversion follows these rules:
    1. The '__class__' value is converted to PascalCase and prefixed with 'Elixir.'
    2. All dictionary keys are converted to atoms only if they are in the SAFE_ATOMS set
    3. The '__class__' key is removed from the final struct
    4. A '__struct__' key is added with the module name as an atom

    NOTE: This implementation does not verify that the target struct module exists in the Elixir
    system. It's the caller's responsibility to ensure that the struct modules are defined and
    available at runtime.

    Examples of class name conversion:
    - 'user' -> Elixir.User
    - 'data.types.point' -> Elixir.Data.Types.Point
"""
from erlport.erlterms import Atom
from lux.packages import list_packages, get_package_version, safe_import
import ast

def encode_term(term):
    """Convert Python types to Erlang terms."""
    if term is None:
        return Atom(b'nil')
    elif isinstance(term, str):
        return term.encode('utf-8')  # Convert strings to binary for proper Elixir string handling
    elif isinstance(term, (int, float, bool)):
        return term
    elif isinstance(term, tuple):
        return tuple([encode_term(item) for item in term])
    elif isinstance(term, list):
        return [encode_term(item) for item in term]
    elif isinstance(term, dict):
        if "__class__" in term:
            # Convert Python class name to Elixir module name format
            class_name = term["__class__"]
            module_parts = class_name.split('.')
            # Convert first letter of each part to uppercase, rest lowercase
            module_name = '.'.join(p[0].upper() + p[1:].lower() for p in module_parts)
            # Prefix with Elixir. for proper module name
            module_name = f"Elixir.{module_name}"
            
            # Create a new dict without the __class__ key
            struct_dict = term.copy()
            del struct_dict["__class__"]
            
            # Convert all keys to atoms and values to Erlang terms
            encoded_dict = {}
            for k, v in struct_dict.items():
                encoded_dict[Atom(k.encode('utf-8'))] = encode_term(v)
            
            # Add the __struct__ field as an atom
            if not "__struct__" in term:
                encoded_dict[Atom(b'__struct__')] = Atom(module_name.encode('utf-8'))
            return encoded_dict
        else:
            # Regular dict - encode both keys and values
            return {encode_term(k): encode_term(v) for k, v in term.items()}
    return term

def decode_term(term):
    """Convert Erlang terms to Python types."""
    if isinstance(term, Atom):
        return term.decode('utf-8')
    elif isinstance(term, tuple):
        return tuple([decode_term(item) for item in term])
    elif isinstance(term, list):
        return [decode_term(item) for item in term]
    elif isinstance(term, dict):
        return {decode_term(k): decode_term(v) for k, v in term.items()}
    elif isinstance(term, bytes):
        return term.decode('utf-8')
    return term

def is_expression(node):
    """Check if an AST node represents an expression that can be evaluated."""
    return isinstance(node, (ast.Expr, ast.Expression))

def execute_simple(code, variables=None):
    if isinstance(code, bytes):
        code = code.decode('utf-8')
    globals_dict = {'__builtins__': __builtins__}
    tree = ast.parse(code, mode='exec')

    exec(ast.unparse(ast.Module(body=tree.body, type_ignores=[])), globals_dict)


def execute(code, variables=None):
    """Execute Python code with optional variable bindings."""
    try:
        # Handle string encoding from Erlang
        if isinstance(code, bytes):
            code = code.decode('utf-8')

        # Create a shared globals dictionary that includes builtins
        globals_dict = {'__builtins__': __builtins__}
        
        # Add variables to globals so they're accessible everywhere
        if variables:
            globals_dict.update({
                (k.decode('utf-8') if isinstance(k, bytes) else str(k)): decode_term(v) 
                for k, v in variables.items()
            })

        # Parse the code into an AST
        tree = ast.parse(code, mode='exec')
        
        # If the code is empty, return None
        if not tree.body:
            return None
            
        # If we have multiple statements
        if len(tree.body) > 1:
            # Execute all but the last statement
            exec(ast.unparse(ast.Module(body=tree.body[:-1], type_ignores=[])), globals_dict)
            
        # Get the last statement
        last = tree.body[-1]
        
        # If the last statement is an expression, evaluate it
        if isinstance(last, ast.Expr):
            result = eval(ast.unparse(last.value), globals_dict)
            return encode_term(result)
        elif isinstance(last, ast.ClassDef) and '__lux_function__' in globals_dict:
            exec(ast.unparse(tree.body[-1]), globals_dict)
            func = globals_dict.get('__lux_function__')
            args = globals_dict.get('__lux_function_args__', [])
            constructor_args = globals_dict.get('__lux_constructor_args__', [])

            cls = globals_dict.get(last.name)
            cls_instance = cls.new(*constructor_args)
            result = getattr(cls_instance, func)(*args) if func else None
            return encode_term(result)
        else:
            # Execute the last statement if it's not an expression
            exec(ast.unparse(ast.Module(body=[last], type_ignores=[])), globals_dict)
            return None
            
    except Exception as e:
        # Instead of returning an error dict, raise the exception
        # This will be caught by Erlport and converted to an Elixir error
        raise RuntimeError(f"{type(e).__name__}: {str(e)}") 

def get_available_packages():
    """Get a list of available packages and their versions."""
    return encode_term(list_packages())

def check_package(package_name):
    """Check if a package is available and get its version."""
    if isinstance(package_name, bytes):
        package_name = package_name.decode('utf-8')
    version = get_package_version(package_name)
    return encode_term({
        "available": version is not None,
        "version": version if version else None
    })

def import_package(package_name):
    """Attempt to import a package."""
    if isinstance(package_name, bytes):
        package_name = package_name.decode('utf-8')
    success, error = safe_import(package_name)
    return encode_term({
        "success": success,
        "error": error if error else None
    })