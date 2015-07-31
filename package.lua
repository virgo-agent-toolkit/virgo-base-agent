return {
  name = "virgo-agent-toolkit/virgo",
  version = "2.0.1-dev",
  luvi = {
    version = "2.1.7-sigar",
    flavor = "sigar",
    url = "https://github.com/virgo-agent-toolkit/luvi/releases/download/v%s-sigar/luvi-%s-%s"
  },
  dependencies = {
    "luvit/luvit@2",
    "luvit/tap@0.1",
    "rphillips/hsm@1",
    "rphillips/logging@1.0",
    "creationix/semver@1.0",
    "virgo-agent-toolkit/async@1",
    "virgo-agent-toolkit/line-emitter@0.6",
    "virgo-agent-toolkit/split-stream@0.6",
    "virgo-agent-toolkit/request@1"
  },
  files = {
    "**.lua",
    "!lit*",
    "!test*"
  }
}
