"""GHCi REPL support"""

load(":tools.bzl",
     "get_ghci"
)

load("@bazel_skylib//:lib.bzl",
     "paths"
)

load(":providers.bzl",
     "HaskellPackageInfo"
)

load(":path_utils.bzl",
     "import_hierarchy_root",
)

load(":hsc2hs.bzl",
     "hsc_to_hs",
)

def _haskell_repl_impl(ctx):
  args = ["-hide-all-packages"]

  # Generate options that bring "prebuilt dependencies" in scope.
  args += ["-package " + dep for dep in ctx.attr.prebuilt_dependencies]

  # Generate options that bring Haskell dependencies in scope.
  for dep in ctx.attr.deps:
    if HaskellPackageInfo in dep:
      # I'm not sure about exact logic here. Should we make visible only
      # direct dependencies or also all transitive dependencies? I think
      # Stack/Cabal only make direct dependencies visible, and one should
      # add transitive dependencies explicitly.
      pkg = dep[HaskellPackageInfo]
      args += ["-package {0}".format(pkg.name)]
      args += ["-package-db {0}".format(c.dirname) for c in pkg.caches.to_list()]

  # In addition to dependencies we want to give access to the code in
  # development, which may not compile fully yet.
  args += ["-i{0}".format(import_hierarchy_root(ctx))]

  # Add the collection of input files preprocessing hsc sources properly.
  srcs = hsc_to_hs(ctx)
  args += [f.path for f in srcs]

  ctx.actions.expand_template(
    template = ctx.file._ghci_repl_wrapper,
    output = ctx.outputs.executable,
    substitutions = {
      "{GHCi}": get_ghci(ctx).path,
      "{ARGS}": " ".join(args),
    },
    is_executable = True,
  )

  return [DefaultInfo(
    executable = ctx.outputs.executable,
    runfiles = ctx.runfiles(files=srcs, transitive_files=depset(ctx.files.deps)),
  )]

haskell_repl = rule(
  _haskell_repl_impl,
  executable = True,
  attrs = {
    "srcs": attr.label_list(
      allow_files = FileType([".hs", ".hsc", ".lhs", ".hs-boot", ".lhs-boot", ".h"]),
      doc = "Haskell source files you are working on, not all of them must compile.",
    ),
    "src_strip_prefix": attr.string(
      doc = "Directory in which module hierarchy starts.",
    ),
    "deps": attr.label_list(
      doc = "List of Haskell dependencies to be available in the REPL.",
    ),
    "prebuilt_dependencies": attr.string_list(
      doc = "Non-Bazel supplied Cabal dependencies.",
    ),
    # XXX Consider making this private. Blocked on
    # https://github.com/bazelbuild/bazel/issues/4366.
    "version": attr.string(
      default = "1.0.0",
      doc = "Library/binary version. Internal - do not use."
    ),
    "_ghci_repl_wrapper": attr.label(
      allow_single_file = True,
      default = Label("@io_tweag_rules_haskell//haskell:ghci-repl-wrapper.sh"),
    ),
    "_ghc_defs_cleanup": attr.label(
      allow_single_file = True,
      default = Label("@io_tweag_rules_haskell//haskell:ghc-defs-cleanup.sh"),
    ),
  },
  toolchains = ["@io_tweag_rules_haskell//haskell:toolchain"],
)
"""Produce a script that calls GHCi with all files of current project and
dependencies in scope. Not all files specified in `srcs` must compile, GHCi
will skip failing modules and load others.

Example of use:

```
$ bazel build test:my-repl
$ bazel-bin/test/my-repl
```
"""
