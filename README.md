[![Build Status](https://travis-ci.org/virgo-agent-toolkit/virgo-base-agent.svg?branch=luvi-up)](https://travis-ci.org/virgo-agent-toolkit/virgo-base-agent) [![Build status](https://ci.appveyor.com/api/projects/status/k7jglhodjrubcw0y/branch/luvi-up?svg=true)](https://ci.appveyor.com/project/racker-buildbot/virgo-base-agent/branch/luvi-up)

Virgo
=====

Virgo is a project for building on-host agents. Virgo's goal is to provide shared infrastructure for various types of agents while maintaining a small footprint.

Virgo provides:

1. A high level scripting language in Lua using Luvit (an event driven framework).
2. The ability to perform self updating.
3. Crash capturing and reporting through Google's Breakpad.
4. Packages, Installers and related goodies.
5. Automatic .zip bundle generation from a directory (ie, easy deployment).
6. Automatic versioning from .git introspection of both virgo and the bundle.

The first agent to use this infrastructure is the Rackspace Cloud Monitoring agent.

Join in and build your agent with us. We're in **#virgo on irc.freenode.net** and [Virgo Agent Toolkit Dev][devGG] and [Virgo Agent Toolkit User][userGG] on GoogleGroups.

[devGG]: https://groups.google.com/forum/#!forum/virgo-agent-toolkit-dev
[userGG]: https://groups.google.com/forum/#!forum/virgo-agent-toolkit-user

License
=======

virgo is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html

Build and Testing
=================

```
make
make test
```

Versioning
==========

The agent is versioned with a three digit dot seperated "semantic
version" with the template being x.y.z. An example being e.g. 1.4.2. The
rough meaning of each of these parts are:

- major version numbers will change when we make a backwards
  incompatible change to the bundle format. Binaries can only run
  bundles with identical major version numbers. e.g. a binary of version
  2.3.1 can only run bundles starting with 2.

- minor version numbers will change when we make backwards compatible
  changes to the bundle format. Binaries can only run bundles with minor
  versions that are greater than or equal to the bundle version. e.g. a
  binary of version 2.3.1 can run a 2.3.4 bundle but not a 2.2.1 bundle.

- patch version numbers will change everytime a new bundle is released.
  It has no semantic meaning to the versioning.

The zip file bundle and the binary shipped in an rpm/deb/msi will be
identical. If the binary is 1.4.2 then the bundle will be 1.4.2.

Building for Rackspace Cloud Monitoring
=======================================

Rackspace customers: Virgo is the open source project for the Rackspace
Cloud Monitoring agent. Feel free to build your own copy from this
source.

But! Please don't contact Rackspace Support about issues you encounter
with your custom build. We can't support every change people may make
and master might not be fully tested.

