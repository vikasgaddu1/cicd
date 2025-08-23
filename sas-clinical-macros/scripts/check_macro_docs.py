#!/usr/bin/env python3
"""
Check SAS macro documentation for completeness and consistency.
Used by pre-commit hooks to ensure all macros are properly documented.
"""

import sys
import re
from pathlib import Path

def check_macro_documentation(filepath):
    """Check if a SAS macro file has proper documentation."""
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    errors = []
    warnings = []
    
    # Check for header comment block
    if not re.search(r'/\*{3,}', content[:500]):
        errors.append(f"Missing header comment block in {filepath}")
    
    # Check for macro name documentation
    macro_pattern = r'%macro\s+(\w+)'
    macros = re.findall(macro_pattern, content, re.IGNORECASE)
    
    for macro_name in macros:
        # Check for Purpose/Description
        if not re.search(rf'(Purpose|Description|Function).*{macro_name}', content, re.IGNORECASE):
            warnings.append(f"Macro '{macro_name}' lacks purpose/description documentation")
        
        # Check for Parameters documentation
        param_pattern = rf'%macro\s+{macro_name}\s*\((.*?)\)'
        param_match = re.search(param_pattern, content, re.IGNORECASE | re.DOTALL)
        
        if param_match and param_match.group(1).strip():
            params = [p.strip().split('=')[0] for p in param_match.group(1).split(',')]
            for param in params:
                if param and not re.search(rf'(Parameter|Param|Input).*{param}', content, re.IGNORECASE):
                    warnings.append(f"Parameter '{param}' in macro '{macro_name}' is not documented")
        
        # Check for Author
        if not re.search(r'(Author|Created by|Developer)', content, re.IGNORECASE):
            warnings.append(f"Missing author information in {filepath}")
        
        # Check for Date/Version
        if not re.search(r'(Date|Version|Created|Modified)', content, re.IGNORECASE):
            warnings.append(f"Missing date/version information in {filepath}")
        
        # Check for Usage example
        if not re.search(r'(Usage|Example|Sample)', content, re.IGNORECASE):
            warnings.append(f"Missing usage example for macro '{macro_name}'")
    
    return errors, warnings

def main():
    """Main function to check all modified SAS macro files."""
    
    # Get file paths from command line arguments or check all macros
    if len(sys.argv) > 1:
        files = sys.argv[1:]
    else:
        macro_dir = Path('sas-clinical-macros/macros')
        if not macro_dir.exists():
            print("Macro directory not found. Running from correct location?")
            return 0
        files = list(macro_dir.glob('*.sas'))
    
    all_errors = []
    all_warnings = []
    
    for filepath in files:
        filepath = Path(filepath)
        if filepath.suffix == '.sas' and 'macros' in str(filepath):
            errors, warnings = check_macro_documentation(filepath)
            all_errors.extend(errors)
            all_warnings.extend(warnings)
    
    # Print results
    if all_errors:
        print("DOCUMENTATION ERRORS FOUND:")
        for error in all_errors:
            print(f"  ERROR: {error}")
    
    if all_warnings:
        print("\nDOCUMENTATION WARNINGS:")
        for warning in all_warnings:
            print(f"  WARNING: {warning}")
    
    if not all_errors and not all_warnings:
        print("✓ All macro documentation checks passed")
    
    # Return non-zero exit code if errors found
    return 1 if all_errors else 0

if __name__ == '__main__':
    sys.exit(main())