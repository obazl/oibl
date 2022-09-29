SRCS = [
    "load_dune.c",
    "config_bazel.c",
    "config_mibl.c",
    "config_opam.c",
    "config_s7.c",
    "error_handler.c",
    "fs.c",
    "utils.c",
    "debug.c"
]

## selects are not iterable
LINUX_SRCS = ["strlcat.c", "strlcpy.c", "strnstr.c"]

def linux_srcs():
    locs = []
    for f in LINUX_SRCS:
        locs.append("$(location {})".format(f))
    return " ".join(locs)

def mkhdr_srcs():
    locs = []
    for f in SRCS:
        locs.append("$(location {})".format(f))
    args = " ".join(locs) + "    $(location ansi_colors.h)"
    args = args + select({
        "//bzl/host:linux": linux_srcs(),
        "//conditions:default": ""
    }) + select({
        ":dbg_mode": " $(location debug.c)",
        "//conditions:default": ""
    })
    return args

