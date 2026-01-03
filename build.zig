const std = @import("std");
const protobuf = @import("protobuf");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) !void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
    });

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    // Create the spiffeid module first so it can be imported by other modules
    const spiffeid_mod = b.addModule("spiffeid", .{
        .root_source_file = b.path("src/spiffeid/root.zig"),
        .target = target,
    });

    const mod = b.addModule("ziffe", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
        // required for openssl as a C library
        .link_libc = true,
    });

    // Add spiffeid as an import to the main module
    mod.addImport("spiffeid", spiffeid_mod);

    // Vendor OpenSSL from source tarball. We build it
    // in-place within the fetched source tree and reuse the cached result.
    const openssl_dep = b.dependency("openssl", .{});
    const openssl_src = openssl_dep.path(".");
    const openssl_build = blk: {
        const script = std.fmt.allocPrint(
            b.allocator,
            \\set -euxo pipefail
            \\if [ ! -f libcrypto.a ]; then
            \\  CFLAGS="-fPIC" ./Configure no-shared no-tests
            \\  make -j"$(nproc)" build_sw
            \\fi
        ,
            .{},
        ) catch @panic("OOM");
        const run = b.addSystemCommand(&.{ "bash", "-c", script });
        run.cwd = openssl_src;
        break :blk run;
    };
    const openssl_include = openssl_dep.path("include");
    const openssl_libcrypto = openssl_dep.path("libcrypto.a");
    const openssl_libssl = openssl_dep.path("libssl.a");

    // Point the module at the vendored headers so `@cImport` can find them.
    mod.addIncludePath(openssl_include);
    mod.addImport("protobuf", protobuf_dep.module("protobuf"));

    const gen_proto = b.step("gen-proto", "generates zig files from workload API protobuf definition");
    const protoc_step = protobuf.RunProtocStep.create(protobuf_dep.builder, target, .{
        .destination_directory = b.path("src/proto"),
        .source_files = &.{
            "protos/workloadapi.proto",
        },
        .include_directories = &.{},
    });

    gen_proto.dependOn(&protoc_step.step);

    // Creates an executable that will run `test` blocks from the provided module.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    mod_tests.step.dependOn(&openssl_build.step);
    mod_tests.addIncludePath(openssl_include);
    mod_tests.addObjectFile(openssl_libcrypto);
    mod_tests.addObjectFile(openssl_libssl);
    mod_tests.linkSystemLibrary("dl");
    mod_tests.linkSystemLibrary("pthread");
    mod_tests.linkLibC();

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
