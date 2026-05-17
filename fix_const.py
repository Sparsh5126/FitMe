import subprocess
import re

def main():
    print("Running dart analyze...")
    result = subprocess.run(["dart", "analyze"], capture_output=True, text=True, shell=True)
    
    lines = result.stdout.split('\n')
    errors = []
    
    for line in lines:
        if "error -" in line and ("const" in line.lower() or "constant" in line.lower()):
            # Parse filename and line number
            # Format: error - path:line:col - message
            parts = line.split('-')
            if len(parts) >= 3:
                location = parts[1].strip()
                loc_parts = location.split(':')
                if len(loc_parts) >= 2:
                    filepath = loc_parts[0].strip()
                    linenum = int(loc_parts[1].strip())
                    errors.append((filepath, linenum))

    print(f"Found {len(errors)} constant-related errors.")
    
    # Group by file
    from collections import defaultdict
    file_errors = defaultdict(set)
    for path, line in errors:
        file_errors[path].add(line)
        
    for filepath, line_nums in file_errors.items():
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.readlines()
                
            changed = False
            # Sort line numbers descending to avoid shifting indices if we were deleting lines,
            # though here we are just modifying lines in-place, sorting is still good.
            for linenum in sorted(line_nums, reverse=True):
                # Search backwards up to 20 lines to find the 'const' keyword
                for offset in range(20):
                    idx = linenum - 1 - offset
                    if idx >= 0 and idx < len(content):
                        old_line = content[idx]
                        # Remove only the first occurrence of 'const ' on that line to be safe
                        new_line = re.sub(r'\bconst\s+', '', old_line, count=1)
                        if old_line != new_line:
                            content[idx] = new_line
                            changed = True
                            print(f"Removed const in {filepath} at line {idx + 1} (error was at line {linenum})")
                            break
                        
            if changed:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.writelines(content)
                print(f"Updated {filepath}")
        except Exception as e:
            print(f"Failed to process {filepath}: {e}")

if __name__ == "__main__":
    main()
