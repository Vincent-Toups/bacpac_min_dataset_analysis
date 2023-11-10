#!/usr/bin/python3
import os
import re
import argparse
from collections import defaultdict

# Set up the command-line argument parsing
parser = argparse.ArgumentParser(description="Generate pseudoMakefile entries for R and Python scripts.")
parser.add_argument('--directory', default=os.getcwd(), help="Directory containing the R and Python files (default: current working directory)")
args = parser.parse_args()

# Normalize the directory path
args.directory = os.path.normpath(args.directory)

# Regular expressions to find file read/write operations and PNG creations
read_pattern = re.compile(r'read.*?\(["\'](.+?\.csv)["\']')
write_pattern = re.compile(r'to_csv\(["\'](.*?)["\']')
write_csv_pattern = re.compile(r'\.write_csv\(["\'](.*?)["\']')  # For write_csv in pandas
write_r_pattern = re.compile(r'write.*?\.csv\(["\'](.*?)["\']')
png_pattern = re.compile(r'save.*?["\'](.*?\.png)["\']')

# Holder for all makefile entries and list of targets
makefile_entries = []
target_files = set()

# Dictionary to collect the .png and .csv files
generated_files = defaultdict(set)

# Get all R and Python files from the specified directory
for root, dirs, files in os.walk(args.directory):
    for file in files:
        # Skip Emacs temporary or backup files
        if file.endswith('~') or file.startswith('.#'):
            continue

        if file.endswith('.R') or file.endswith('.py'):
            filepath = os.path.join(root, file)
            # Compute the relative path from the search directory
            relative_filepath = os.path.relpath(filepath, args.directory)
            with open(filepath, 'r') as f:
                content = f.read()

            # Find CSV reads and writes and PNG creations in the content
            reads = read_pattern.findall(content)
            writes = write_pattern.findall(content) + write_r_pattern.findall(content) + write_csv_pattern.findall(content)
            pngs = png_pattern.findall(content)

            # Register generated files
            for write in writes:
                generated_files[write].add(relative_filepath)
            for png in pngs:
                generated_files[png].add(relative_filepath)

            # Collect targets for later analysis
            target_files.update(writes + pngs)

            # Create makefile entries
            dependencies = ' '.join(reads + [relative_filepath])
            targets = ' '.join(writes + pngs)
            if targets:
                # Determine the appropriate interpreter
                interpreter = 'Rscript' if file.endswith('.R') else 'python3'

                entry = f"{targets}: {dependencies}\n\t{interpreter} {relative_filepath}\n"
                makefile_entries.append(entry)

# Write the result to "pseudoMakefile"
with open('pseudoMakefile', 'w') as f:
    f.write('\n'.join(makefile_entries))

# Check for pngs/csvs without a generating recipe
all_files = set(os.path.relpath(os.path.join(dp, f), args.directory)
                for dp, dn, filenames in os.walk(args.directory) 
                for f in filenames 
                if f.endswith(('.png', '.csv')))

files_without_recipe = all_files - target_files

# Print warnings if any
if files_without_recipe:
    print("Warning: The following files do not have a generating recipe:")
    for file in files_without_recipe:
        print(file)

print("pseudoMakefile has been created or overwritten.")
