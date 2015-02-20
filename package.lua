return {
  name = "virgo-agent-toolkit/virgo",
  version = "0.10.0",
  dependencies = {
    "luvit/luvit@1.9.1",
    "rphillips/async@0.0.2",
    "rphillips/hsm@0.0.2",
    "rphillips/line-emitter@0.3.3",
    "rphillips/logging@0.1.2",
    "rphillips/request@0.0.3",
    "rphillips/split-stream@0.4.0",
  },
  files = {
    "*.lua",
    "!lit*",
    "!test*"
  }
}
