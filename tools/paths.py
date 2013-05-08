import sys
import os

import optloader

AGENT = None
LUVIT = None
BUNDLE_DIR = None


def _abs_path(*args):
    return os.path.abspath(os.path.join(*args))

_options = optloader.load_options('platform.gypi')['variables']

ROOT = _options['BUNDLE_DIR']  # os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BUNDLE_DIR = _abs_path(ROOT, _options['BUNDLE_DIR'])
BUNDLE_NAME = _options['BUNDLE_NAME']

if sys.platform == "win32":
    _base_options = optloader.load_options('options.gypi')['variables']
    if _base_options['virgo_debug'] == 'true':
        BUILDTYPE = 'Debug'
    else:
        BUILDTYPE = 'Release'

    BUILD_DIR = _abs_path(ROOT, 'base', BUILDTYPE)
    LUVIT = _abs_path(BUILD_DIR, 'luvit.exe')
    AGENT = _abs_path(BUILD_DIR, 'virgo.exe')
else:
    BUILDTYPE = os.environ.get('BUILDTYPE', 'Debug')
    BUILD_DIR = _abs_path(ROOT, 'out', BUILDTYPE)
    LUVIT = _abs_path(BUILD_DIR, 'luvit')
    AGENT = _abs_path(BUILD_DIR, _options['PKG_NAME'])


if __name__ == "__main__":
    os.environ['AGENT_BIN'] = AGENT
    os.environ['LUVIT_BIN'] = LUVIT
