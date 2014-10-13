#!/usr/bin/env python

import os
import sys
import shutil

from version import full_version
from optparse import OptionParser

import pkgutils


def main():
    usage = "usage: %prog [destination path]"
    parser = OptionParser(usage=usage)
    parser.add_option("", "--set-version", action="store", dest="version", default=full_version(),
            help="set the version in the file name")
    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.print_usage()
        sys.exit(1)

    dest = args[0]
    orig_dest = dest
    build_dir = pkgutils.package_builder_dir(setversion=options.version)
    binary_name = pkgutils.package_binary()
    binary = os.path.join(build_dir, binary_name)

    print(build_dir)
    print(binary_name)
    print(binary)

    dest = os.path.join(dest, '%s-rackspace-monitoring-agent-%s' % (pkgutils.pkg_dir(),
      options.version))
    if pkgutils.pkg_type() == 'windows':
        dest += '.msi'
        arch = os.environ.get('BUILD_ARCH', '')
        arch_str = '-' + arch
        if arch == 'ia32':
            # preserve old binary path
            hard_file = os.path.join(orig_dest, 'rackspace-monitoring-agent.msi')
            shutil.copyfile(binary, hard_file)

        hard_file = os.path.join(orig_dest, 'rackspace-monitoring-agent%s.msi' % arch_str)
        shutil.copyfile(binary, hard_file)
    else:
        shutil.copyfile(binary, dest)

    onlyfiles = [f for f in os.listdir(orig_dest) if os.path.isfile(os.path.join(orig_dest, f))]
    for f in onlyfiles:
        print(f)

    if pkgutils.pkg_type() != 'windows':
        shutil.move(binary + ".sig", dest + ".sig")


if __name__ == "__main__":
    main()
