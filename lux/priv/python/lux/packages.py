"""
Package management utilities for Lux.

This module provides functionality to:
1. List installed packages and their versions
2. Safely import external packages
3. Verify package availability
"""
from importlib import metadata, import_module
import sys
from typing import Dict, List, Optional, Tuple

def list_packages() -> Dict[str, str]:
    """
    List all installed Python packages and their versions.
    
    Returns:
        Dict[str, str]: A dictionary mapping package names to their versions
    """
    return {dist.name: dist.version for dist in metadata.distributions()}

def get_package_version(package_name: str) -> Optional[str]:
    """
    Get the version of an installed package.
    
    Args:
        package_name (str): Name of the package
        
    Returns:
        Optional[str]: Version string if package is installed, None otherwise
    """
    try:
        return metadata.version(package_name)
    except metadata.PackageNotFoundError:
        return None

def safe_import(package_name: str) -> Tuple[bool, Optional[str]]:
    """
    Safely attempt to import a package.
    
    Args:
        package_name (str): Name of the package to import
        
    Returns:
        Tuple[bool, Optional[str]]: (success, error_message)
    """
    try:
        if package_name in sys.modules:
            return True, None
            
        import_module(package_name)
        return True, None
    except ImportError as e:
        return False, str(e)
    except Exception as e:
        return False, f"Unexpected error importing {package_name}: {str(e)}" 