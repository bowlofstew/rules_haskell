package(default_testonly = 1)

load("@io_tweag_rules_haskell//haskell:haskell.bzl",
     "haskell_library",
     "haskell_repl",
)

haskell_library(
  name = "hs-lib",
  srcs = ["Foo.hs"],
  prebuilt_dependencies = ["base"],
  visibility = ["//visibility:public"],
)

haskell_repl(
  name = "haskell_repl",
  srcs = glob(["src/*.hs", "src/*.hsc"]),
  src_strip_prefix = "src",
  deps = [":hs-lib"],
  prebuilt_dependencies = ["base", "array"],
  visibility = ["//visibility:public"],
)
