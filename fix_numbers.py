#!/usr/bin/env python3

import re
import os
from pathlib import Path

def add_underscores_to_number(match):
    number = match.group(0)
    # Skip if it's a hex number or already has underscores
    if 'x' in number or '_' in number:
        return number
    
    # Skip if it's a decimal number
    if '.' in number:
        return number
        
    # Skip if it's a string (surrounded by quotes)
    if match.start() > 0 and match.string[match.start()-1] in ['"', "'"]:
        return number
        
    # Skip if it's part of a larger identifier
    if match.start() > 0 and match.string[match.start()-1].isalnum():
        return number
    if match.end() < len(match.string) and match.string[match.end()].isalnum():
        return number
    
    # Add underscores every 3 digits from right
    parts = []
    number = number[::-1]  # Reverse to process from right
    for i in range(0, len(number), 3):
        parts.append(number[i:i+3])
    return '_'.join(parts)[::-1]  # Join and reverse back

def process_file(file_path):
    try:
        # Try UTF-8 first
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            # Try latin-1 if UTF-8 fails
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return
    
    # Find numbers with 5 or more digits
    pattern = r'\b\d{5,}\b'
    new_content = re.sub(pattern, add_underscores_to_number, content)
    
    if content != new_content:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated {file_path}")
        except Exception as e:
            print(f"Error writing to {file_path}: {e}")

def main():
    # Get the current directory
    current_dir = Path.cwd()
    
    # Find all .ex and .exs files in the lux directory
    for file_path in current_dir.rglob('*.ex*'):
        if 'lux' in file_path.parts:
            process_file(file_path)

if __name__ == '__main__':
    main() 