"""Tests for the atoms module."""
import pytest
from erlport.erlterms import Atom

def test_atom_creation_with_str():
    """Test creating an Atom with a string."""
    atom = Atom(b"test")
    assert isinstance(atom, bytes)
    assert atom == b"test"

def test_atom_creation_with_bytes():
    """Test creating an Atom with bytes."""
    atom = Atom(b"test")
    assert isinstance(atom, bytes)
    assert atom == b"test"

def test_atom_creation_invalid_type():
    """Test that creating an Atom with invalid type raises TypeError."""
    with pytest.raises(TypeError) as exc_info:
        Atom(123)
    assert "bytes object expected" in str(exc_info.value)

def test_atom_repr():
    """Test the string representation of Atom."""
    atom = Atom(b"test")
    assert repr(atom) == "Atom(b'test')"

def test_atom_str():
    """Test string conversion of Atom."""
    atom = Atom(b"test")
    assert str(atom) == "b'test'"
    
    # Test with non-ASCII characters
    atom = Atom("héllo".encode('utf-8'))
    assert str(atom) == "{}".format("héllo".encode('utf-8'))

def test_atom_equality():
    """Test equality comparison of Atoms."""
    atom1 = Atom(b"test")
    atom2 = Atom(b"test")
    atom3 = Atom(b"other")
    
    assert atom1 == atom2
    assert atom1 != atom3
    assert atom1 != "test"  # Compare with non-Atom

def test_atom_hash():
    """Test that Atoms can be used as dictionary keys."""
    atom1 = Atom(b"test")
    atom2 = Atom(b"test")
    atom3 = Atom(b"other")
    
    # Create a dictionary with an atom key
    d = {atom1: "value"}
    
    # Test dictionary operations
    assert d[atom1] == "value"
    assert d[atom2] == "value"  # Same atom should work
    assert atom3 not in d  # Different atom should not be found

def test_atom_with_unicode():
    """Test Atom handling of Unicode characters."""
    # Test various Unicode strings
    test_strings = [
        "héllo",  # Accented characters
        "こんにちは",  # Japanese
        "🌟",  # Emoji
        "α β γ"  # Greek letters
    ]
    
    for s in test_strings:
        atom = Atom(s.encode('utf-8'))
        assert str(atom) == "{}".format(s.encode('utf-8'))
        assert atom == s.encode('utf-8')