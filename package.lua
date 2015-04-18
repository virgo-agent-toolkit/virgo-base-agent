return {
  name = "virgo-agent-toolkit/virgo",
  version = "0.13.1",
  dependencies = {
    "luvit/luvit@2.0.6",
    "creationix/semver@1.0.1",
    "rphillips/hsm@0.0.2",
    "rphillips/logging@0.1.4",
    "virgo-agent-toolkit/async@1",
    "virgo-agent-toolkit/line-emitter@0.5.0",
    "virgo-agent-toolkit/split-stream@0.5.3",
    "virgo-agent-toolkit/request@1"
  },
  files = {
    "**.lua",
    "!lit*",
    "!test*"
  }
}
