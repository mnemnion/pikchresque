// Build script for pikchresque
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zitron_dep = b.dependency("zitron", .{
        .target = b.graph.host,
        .optimize = .Debug,
        .enum_file = true,
        .show_conflicts = true,
    });
    const zitron_exe = zitron_dep.artifact("zitron");

    const grammar_run = b.addRunArtifact(zitron_exe);
    const grammar_write_in = b.addWriteFiles();
    const grammar_input_dir = grammar_write_in.addCopyDirectory(b.path("src"), "pikchr_grammar_in", .{});
    grammar_run.setCwd(grammar_input_dir);
    grammar_run.addArg("pikchr.zy");
    grammar_run.step.dependOn(&grammar_write_in.step);

    const grammar_write_out = b.addWriteFiles();
    grammar_write_out.step.dependOn(&grammar_run.step);
    const grammar_output_dir = grammar_write_out.addCopyDirectory(grammar_input_dir, "", .{
        .exclude_extensions = &.{"zy"},
    });

    const install_generated_parser = b.addInstallFile(grammar_output_dir.path(b, "pikchr.zig"), "grammar/pikchr.zig");
    install_generated_parser.step.dependOn(&grammar_write_out.step);
    const install_generated_tokens = b.addInstallFile(grammar_output_dir.path(b, "TokenKind.zig"), "grammar/TokenKind.zig");
    install_generated_tokens.step.dependOn(&grammar_write_out.step);
    const install_generated_report = b.addInstallFile(grammar_output_dir.path(b, "pikchr.out"), "grammar/pikchr.out");
    install_generated_report.step.dependOn(&grammar_write_out.step);

    const grammar_step = b.step("grammar", "Generate the Pikchr parser with Zitron");
    grammar_step.dependOn(&install_generated_parser.step);
    grammar_step.dependOn(&install_generated_tokens.step);
    grammar_step.dependOn(&install_generated_report.step);

    const grammar_mod = b.createModule(.{
        .root_source_file = grammar_output_dir.path(b, "pikchr.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pikchresque_mod = b.addModule("pikchresque", .{
        .root_source_file = b.path("src/pikchresque.zig"),
        .target = target,
        .optimize = optimize,
    });
    pikchresque_mod.addImport("pikchr", grammar_mod);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("pikchr", grammar_mod);

    const lib = b.addLibrary(.{
        .name = "pikchresque",
        .root_module = lib_mod,
    });
    lib.step.dependOn(&grammar_write_out.step);

    b.installArtifact(lib);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("pikchresque", pikchresque_mod);
    exe_mod.link_libc = true;

    const exe = b.addExecutable(.{
        .name = "pikchresque",
        .root_module = exe_mod,
    });
    exe.step.dependOn(&grammar_write_out.step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_pikchresque = b.step("run", "run the pikchresque binary");
    run_pikchresque.dependOn(&run_cmd.step);

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &[0][]const u8{};

    const module_unit_tests = b.addTest(.{
        .root_module = pikchresque_mod,
        .filters = test_filters,
    });
    module_unit_tests.step.dependOn(&grammar_write_out.step);

    const run_module_unit_tests = b.addRunArtifact(module_unit_tests);

    const grammar_unit_tests = b.addTest(.{
        .root_module = grammar_mod,
        .filters = test_filters,
    });
    grammar_unit_tests.step.dependOn(&grammar_write_out.step);
    const run_grammar_unit_tests = b.addRunArtifact(grammar_unit_tests);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .filters = test_filters,
    });
    lib_unit_tests.step.dependOn(&grammar_write_out.step);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
        .filters = test_filters,
    });
    exe_unit_tests.step.dependOn(&grammar_write_out.step);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");

    test_step.dependOn(&run_module_unit_tests.step);
    test_step.dependOn(&run_grammar_unit_tests.step);

    test_step.dependOn(&run_lib_unit_tests.step);

    test_step.dependOn(&run_exe_unit_tests.step);

    const run_kcov = b.addSystemCommand(&.{
        "kcov",
        "--clean",
        "--exclude-line=unreachable,expect(false),@panic,kcov-defer-error,kcov-test-cleanup",
    });
    run_kcov.addPrefixedDirectoryArg("--include-pattern=", b.path("src"));
    const coverage_output = run_kcov.addOutputDirectoryArg(".");

    // Pick your coverage entry point here:
    run_kcov.addArtifactArg(module_unit_tests);

    run_kcov.enableTestRunnerMode();

    const install_coverage = b.addInstallDirectory(.{
        .source_dir = coverage_output,
        .install_dir = .{ .custom = "coverage" },
        .install_subdir = "",
    });

    const coverage_step = b.step("coverage", "Generate coverage (kcov must be installed)");
    coverage_step.dependOn(&install_coverage.step);
}
