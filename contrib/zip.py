#!/usr/bin/env python
import os
import sys
import zipfile

class FileCtx:
    def __init__(self, relpath, realpath):
        self.relpath = relpath
        self.realpath = realpath

class VirgoZip(zipfile.ZipFile):
    def __init__(self, roots, out):
        zipfile.ZipFile.__init__(self, out, 'w', zipfile.ZIP_DEFLATED)
        self.roots = roots
        self.files = {}

    def run(self):
        for root in self.roots:
            for r, dirs, files in os.walk(root):
                for f in files:
                    if not f.endswith('.lua'):
                        continue
                    realpath = os.path.join(r, f)
                    relpath = os.path.relpath(realpath, root)
                    if relpath:
                        fctx = FileCtx(relpath, realpath)
                        self.files[fctx.relpath] = fctx

    def _write(self, ctx):
        print('Adding: ' + ctx.relpath)
        self.write(ctx.realpath, ctx.relpath) 

    def save(self):
        [ self._write(ctx) for _, ctx in sorted(self.files.items()) ]

z = VirgoZip(sys.argv[2:], sys.argv[1])
z.run()
z.save()
z.close()
