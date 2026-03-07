import os
import re

def count_parameters(file_path):
    violations = []
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Improved pattern: 
    # 1. Matches return type (simplified)
    # 2. Matches function name
    # 3. Matches everything inside parentheses (handles multiline)
    # 4. Matches the opening brace
    pattern = r'(?:^|\n)(?:static\s+)?[a-zA-Z_][a-zA-Z0-9_]*\s*\*?\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)\s*\{'
    matches = re.finditer(pattern, content, re.MULTILINE | re.DOTALL)
    
    for match in matches:
        func_name = match.group(1)
        args_str = match.group(2).strip()
        
        # Keywords to exclude
        if func_name in ['if', 'while', 'for', 'switch', 'return']:
            continue

        if not args_str or args_str == "void":
            param_count = 0
        else:
            # Count commas and add 1
            # But be careful of nested parentheses or types (though rare in C params)
            param_count = args_str.count(',') + 1
        
        if param_count > 4:
            violations.append((func_name, param_count))
            
    return violations

def count_header_functions(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Matches function prototypes in headers
    # Handles multiline prototypes
    pattern = r'(?:^|\n)(?:extern\s+)?[a-zA-Z_][a-zA-Z0-9_]*\s*\*?\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*;'
    matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
    
    # Exclude macros or other things that might match
    valid_matches = [m for m in matches if m not in ['if', 'while', 'for', 'switch', 'return', 'include', 'define', 'undef', 'ifdef', 'ifndef', 'endif']]
    
    return len(valid_matches)

def main():
    src_dir = '/home/yinpi/minishell/src'
    
    print("Checking for functions with > 4 parameters...")
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.c'):
                path = os.path.join(root, file)
                violations = count_parameters(path)
                if violations:
                    print(f"File: {path}")
                    for func, count in violations:
                        print(f"  - {func}: {count} parameters")

    print("\nChecking for headers with > 10 functions...")
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.h'):
                path = os.path.join(root, file)
                count = count_header_functions(path)
                if count > 10:
                    print(f"File: {path} has {count} functions")

if __name__ == "__main__":
    main()
