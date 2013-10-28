#!/usr/bin/env python

import sys
import os
import os.path
import re
import array

USAGE = """
Usage: bin2c [file] [output_file] Convert all the file <file.zip> to <file.zip.h>
"""

if len(sys.argv) < 3:
    print USAGE
    sys.exit(1)

r = re.compile("^([a-zA-Z._][a-zA-Z._0-9]*)[.][Zz][Ii][Pp]$")

path = sys.argv[1]
output_path = sys.argv[2]

filename = os.path.basename(path)
m = r.match(filename)
# Allow only filenames that make sense
# as C variable names
if not(m):
    print "Skipped file (unsuitable filename): " + filename
    sys.exit(1)

# Read PNG file as character array
bytes = array.array('B', open(path, "rb").read())
count = len(bytes)

# Create the C header
text = "/* %s - %d bytes */\n" \
    "static const unsigned char %s[] = {\n" % (filename, count, m.group(1))

# Iterate the characters, we want
# lines like:
#   0x01, 0x02, .... (8 values per line maximum)
i = 0
count = len(bytes)
for byte in bytes:
    # Every new line starts with two whitespaces
    if (i % 8) == 0:
        text += "  "
    # Then the hex data (up to 8 values per line)
    text += "0x%02x" % (byte)
    # Separate all but the last values
    if (i + 1) < count:
        text += ", "
    if (i % 8) == 7:
        text += '\n'
    i += 1

# Now conclude the C source
text += "};\n/* End Of File */\n"

open(output_path, 'w').write(text)
