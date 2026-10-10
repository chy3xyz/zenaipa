const std = @import("std");
const db_link = @import("db_link.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // SQL 驱动按需编译/链接：默认 sqlite+postgres（运行时经 ZENAIPA_DB_DRIVER
    // 切换，两者必须编入）；mysql 无人引用，默认禁用省 ~30s/~590MB translate-c。
    // 选择同时转发给框架依赖——它们缺省 `all`，会把未用驱动悄悄带回来。
    const db_opt = b.option([]const u8, "db", "SQL drivers to link: sqlite,postgres[,mysql] (or all)") orelse "sqlite,postgres";
    const features = db_link.parseDb(db_opt) catch @panic("invalid -Ddb= value (all|sqlite|postgres|mysql, comma-list)");
    if (!features.sqlite or !features.postgres)
        @panic("zenaipa links sqlite+postgres unconditionally (runtime-switchable via ZENAIPA_DB_DRIVER); mysql is opt-in: -Ddb=sqlite,postgres,mysql");

    const zigmodu_dep = b.dependency("zigmodu", .{
        .target = target,
        .optimize = optimize,
        .db = db_opt,
    });
    const zent_dep = b.dependency("zent", .{
        .target = target,
        .optimize = optimize,
        .sqlite = features.sqlite,
        .pg = features.postgres,
        .mysql = features.mysql,
    });

    // 构建期版本号注入(运行时 /system/info 与日志使用)。与 CHANGELOG 同步 bump;
    // CI 发版可 -Drelease=x.y.z 覆盖。
    const version = b.option([]const u8, "release", "Version string embedded in /system/info") orelse "0.3.1";
    const build_info = b.addOptions();
    build_info.addOption([]const u8, "version", version);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));
    exe_mod.addImport("zent", zent_dep.module("zent"));
    exe_mod.addOptions("build_info", build_info);
    db_link.link(exe_mod, b, features);

    const exe = b.addExecutable(.{ .name = "zenaipa", .root_module = exe_mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the zenaipa server");
    run_step.dependOn(&run_cmd.step);

    // Admin CLI (create/list administrator accounts)
    const admin_mod = b.createModule(.{
        .root_source_file = b.path("src/admin_cli.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    admin_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));
    admin_mod.addImport("zent", zent_dep.module("zent"));
    admin_mod.addOptions("build_info", build_info);
    db_link.link(admin_mod, b, features);

    const admin_exe = b.addExecutable(.{ .name = "zenaipa-admin", .root_module = admin_mod });
    b.installArtifact(admin_exe);

    const admin_cmd = b.addRunArtifact(admin_exe);
    admin_cmd.step.dependOn(b.getInstallStep());
    const admin_step = b.step("admin", "Admin CLI help; run zig-out/bin/zenaipa-admin create-admin --email you@example.com");
    admin_step.dependOn(&admin_cmd.step);

    // Unit tests
    const tests_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tests_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));
    tests_mod.addImport("zent", zent_dep.module("zent"));
    db_link.link(tests_mod, b, features);

    const tests = b.addTest(.{ .root_module = tests_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // 体积门禁：任一 src/**/*.zig 超过行数预算即失败（防巨型单体回潮）。
    const size_check = b.addSystemCommand(&.{ "/bin/sh", "scripts/check_file_size.sh" });
    const lint_size = b.step("lint-size", "Fail if any src/**/*.zig exceeds the line budget (1800)");
    lint_size.dependOn(&size_check.step);

    // 格式门禁：任一 src/**/*.zig 不符合 zig fmt 即失败（提交前先 `zig fmt src`）。
    const fmt_check = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "--check", "src" });
    const lint_fmt = b.step("lint-fmt", "Fail if any src/**/*.zig is not zig-fmt clean");
    lint_fmt.dependOn(&fmt_check.step);
}
