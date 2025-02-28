"""Tests for the packages module."""
import pytest
from lux.packages import list_packages, get_package_version, safe_import

def test_list_packages():
    """Test listing installed packages."""
    packages = list_packages()
    assert isinstance(packages, dict)
    # Check for some packages we know should be installed (from pyproject.toml)
    assert "pytest" in packages

def test_get_package_version():
    """Test getting package versions."""
    # Test with an installed package
    version = get_package_version("pytest")
    assert version is not None
    assert isinstance(version, str)
    
    # Test with a non-existent package
    version = get_package_version("nonexistent_package_xyz")
    assert version is None

def test_safe_import():
    """Test safe package importing."""
    # Test importing an installed package
    success, error = safe_import("json")  # json is part of standard library
    assert success
    assert error is None
    
    # Test importing a non-existent package
    success, error = safe_import("nonexistent_package_xyz")
    assert not success
    assert isinstance(error, str)
    assert "No module named" in error
    
    # Test importing an already imported package
    success, error = safe_import("json")  # Should work fine when called again
    assert success
    assert error is None 