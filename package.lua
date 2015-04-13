return {
  name = "virgo-agent-toolkit/virgo",
  version = "0.12.14",
  dependencies = {
    "luvit/luvit@2.0.4",
    "creationix/semver@1.0.1",
    "rphillips/async@0.0.2",
    "rphillips/hsm@0.0.2",
    "rphillips/logging@0.1.4",
    "virgo-agent-toolkit/line-emitter@0.5.0",
    "virgo-agent-toolkit/split-stream@0.5.3",
    "virgo-agent-toolkit/request@0.2.3",
  },
  files = {
    "**.lua",
    "!lit*",
    "!test*"
  }
}
