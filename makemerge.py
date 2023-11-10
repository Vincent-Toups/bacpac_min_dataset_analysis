#!/usr/bin/python3

import sys
import argparse
import re

def parse_makefile(filepath):
    with open(filepath, 'r') as file:
        content = file.read()

    # Parse Makefile's targets and their dependencies and commands
    pattern = re.compile(r'^(.+?):\s*(.*?)\n(.*?)\n\n', re.MULTILINE | re.DOTALL)
    entries = pattern.findall(content)
    makefile_dict = {entry[0].strip(): {'deps': entry[1].strip(), 'cmds': entry[2].strip()} for entry in entries}
    
    return makefile_dict

def main(args):
    # Parse both makefiles
    original_makefile = parse_makefile(args.original)
    modifications_makefile = parse_makefile(args.modifications)
    
    # Detect which targets are common and should be replaced
    common_targets = set(original_makefile.keys()) & set(modifications_makefile.keys())
    
    # Begin with all entries from the original makefile
    combined_entries = original_makefile.copy()
    
    # Replace or add entries with those from the modifications makefile
    for target in common_targets.union(modifications_makefile):
        combined_entries[target] = modifications_makefile[target]

    # Format the combined entries for output
    output_lines = []
    for target, info in combined_entries.items():
        entry = f"{target}: {info['deps']}\n\t{info['cmds']}\n"
        output_lines.append(entry)
    
    if args.output == sys.stdout:
        for line in output_lines:
            print(line)
    else:
        with open(args.output, 'w') as file:
            file.write("\n".join(output_lines))
        print(f"Combined makefile has been written to {args.output}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Combine two makefiles.')
    parser.add_argument('--original', default='Makefile', help='Original makefile (default: Makefile)')
    parser.add_argument('--modifications', required=True, help='Makefile with modifications')
    parser.add_argument('--output', nargs='?', type=argparse.FileType('w'), default=sys.stdout, help='Output file (default: stdout)')
    
    args = parser.parse_args()
    main(args)



     