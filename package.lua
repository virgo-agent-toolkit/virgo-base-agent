return {
  name = "virgo-agent-toolkit/virgo",
  version = "0.14.11",
  dependencies = {
    "luvit/luvit@2.1.0",
    "rphillips/hsm@0.0.2",
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
