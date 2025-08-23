#!/usr/bin/env python3
"""
Simple SAS syntax checker for pre-commit hooks.
Replaces npm-based SASjs linting.
"""

import sys
import re
from pathlib import Path

def check_sas_syntax(filepath):
    """Basic SAS syntax validation."""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    errors = []
    warnings = []
    
    # Check for basic syntax issues
    lines = content.split('\n')
    
    for i, line in enumerate(lines, 1):
        # Check for missing semicolons (simple heuristic)
        if line.strip() and not line.strip().startswith('*') and not line.strip().startswith('/*'):
            if not line.rstrip().endswith((';', '/*', '*/', '*', '%')):
                # Check if next line starts with a statement keyword
                if i < len(lines):
                    next_line = lines[i].strip()
                    if next_line and re.match(r'^(data|proc|run|quit|%macro|%mend|%let|%put|%if|%do|%end)', next_line, re.I):
                        warnings.append(f"Line {i}: Possible missing semicolon")
        
        # Check for unmatched quotes
        single_quotes = line.count("'") - line.count("\\'")
        double_quotes = line.count('"') - line.count('\\"')
        
        if single_quotes % 2 != 0:
            errors.append(f"Line {i}: Unmatched single quote")
        if double_quotes % 2 != 0:
            errors.append(f"Line {i}: Unmatched double quote")
    
    # Check for unmatched macro definitions
    macro_count = len(re.findall(r'%macro\s+\w+', content, re.IGNORECASE))
    mend_count = len(re.findall(r'%mend', content, re.IGNORECASE))
    
    if macro_count != mend_count:
        errors.append(f"Unmatched %macro/%mend: {macro_count} macros, {mend_count} mends")
    
    # Check for unmatched do/end blocks
    do_count = len(re.findall(r'\b(do|%do)\b', content, re.IGNORECASE))
    end_count = len(re.findall(r'\b(end|%end)\b', content, re.IGNORECASE))
    
    if abs(do_count - end_count) > 2:  # Allow some flexibility for data step END statements
        warnings.append(f"Possible unmatched do/end blocks: {do_count} do, {end_count} end")
    
    # Check for common issues
    if re.search(r'\.\.', content):
        warnings.append("Double dots (..) found - possible typo")
    
    if re.search(r',,', content):
        warnings.append("Double commas (,,) found - possible typo")
    
    return errors, warnings

def main():
    """Main function to check SAS files."""
    
    if len(sys.argv) < 2:
        print("Usage: check_sas_syntax.py <file1.sas> [file2.sas ...]")
        return 0
    
    has_errors = False
    
    for filepath in sys.argv[1:]:
        filepath = Path(filepath)
        
        if not filepath.exists():
            print(f"File not found: {filepath}")
            continue
        
        if filepath.suffix.lower() != '.sas':
            continue
        
        errors, warnings = check_sas_syntax(filepath)
        
        if errors or warnings:
            print(f"\n{filepath}:")
            
            for error in errors:
                print(f"  ERROR: {error}")
                has_errors = True
            
            for warning in warnings:
                print(f"  WARNING: {warning}")
    
    return 1 if has_errors else 0

if __name__ == '__main__':
    sys.exit(main())