load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LiquidGlass",
    module_name = "LiquidGlass",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/ComponentFlow:ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
