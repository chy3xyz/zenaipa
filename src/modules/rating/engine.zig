const std = @import("std");

/// 六维评分引擎 - 确定性计算
pub const RatingEngine = struct {
    /// 默认权重（千分比）
    pub const DefaultWeights = struct {
        tech: i32 = 200, // 20%
        team: i32 = 180, // 18%
        tokenomics: i32 = 200, // 20%
        community: i32 = 150, // 15%
        liquidity: i32 = 150, // 15%
        compliance: i32 = 120, // 12%
    };

    /// 档位阈值
    pub const GradeThresholds = struct {
        s: i32 = 85,
        a: i32 = 75,
        b: i32 = 60,
        c: i32 = 45,
    };

    /// 置信度阈值（千分比）
    pub const ConfidenceThresholds = struct {
        normal: i32 = 850, // 85%
        medium: i32 = 600, // 60%
    };

    /// 红牌类型
    pub const RedFlag = enum {
        R1, // 全匿名+无审计
        R2, // 前10持仓>60%
        R3, // 90日解锁>30%
        R4, // 立案/处罚/下架
        R5, // 分叉抄袭
        R6, // 深度<5万美元
    };

    /// 六维分数
    pub const SixDimensions = struct {
        tech: i32,
        team: i32,
        tokenomics: i32,
        community: i32,
        liquidity: i32,
        compliance: i32,
    };

    /// 评级结果
    pub const RatingResult = struct {
        base_score: i32,
        base_grade: []const u8,
        redflag_grade: []const u8,
        shadow_grade: []const u8,
        published_grade: []const u8,
        confidence_six: i32,
        redflags: []const RedFlag,
        compound_warning: bool,
    };

    /// 计算基础分数
    pub fn calculateBaseScore(
        dimensions: SixDimensions,
        weights: DefaultWeights,
    ) i32 {
        const total = @as(i64, dimensions.tech) * weights.tech +
            @as(i64, dimensions.team) * weights.team +
            @as(i64, dimensions.tokenomics) * weights.tokenomics +
            @as(i64, dimensions.community) * weights.community +
            @as(i64, dimensions.liquidity) * weights.liquidity +
            @as(i64, dimensions.compliance) * weights.compliance;

        return @intCast(@divTrunc(total + 500, 1000)); // 四舍五入
    }

    /// 分数转档位
    pub fn scoreToGrade(score: i32, thresholds: GradeThresholds) []const u8 {
        if (score >= thresholds.s) return "S";
        if (score >= thresholds.a) return "A";
        if (score >= thresholds.b) return "B";
        if (score >= thresholds.c) return "C";
        return "D";
    }

    /// 应用红牌降档
    pub fn applyRedFlags(
        base_grade: []const u8,
        redflags: []const RedFlag,
    ) []const u8 {
        // 检查封顶红牌（R1/R4）
        for (redflags) |flag| {
            if (flag == .R1 or flag == .R4) {
                return "D";
            }
        }

        // 普通红牌降一档
        if (redflags.len > 0) {
            return downgradeOne(base_grade);
        }

        return base_grade;
    }

    /// 降一档
    fn downgradeOne(grade: []const u8) []const u8 {
        if (std.mem.eql(u8, grade, "S")) return "A";
        if (std.mem.eql(u8, grade, "A")) return "B";
        if (std.mem.eql(u8, grade, "B")) return "C";
        if (std.mem.eql(u8, grade, "C")) return "D";
        return "D";
    }

    /// 计算置信度
    pub fn calculateConfidence(
        coverage: i32, // 0-100
    ) struct { confidence: i32, status: []const u8 } {
        const conf_value = coverage * 10; // 转为千分比
        if (conf_value >= ConfidenceThresholds.normal) {
            return .{ .confidence = conf_value, .status = "normal" };
        }
        if (conf_value >= ConfidenceThresholds.medium) {
            return .{ .confidence = conf_value, .status = "medium" };
        }
        return .{ .confidence = conf_value, .status = "nr" };
    }

    /// 完整评级计算
    pub fn calculateRating(
        alloc: std.mem.Allocator,
        dimensions: SixDimensions,
        weights: DefaultWeights,
        thresholds: GradeThresholds,
        redflags: []const RedFlag,
        coverage: i32,
    ) !RatingResult {
        // 1. 计算基础分数
        const base_score = calculateBaseScore(dimensions, weights);

        // 2. 基础档位
        const base_grade = scoreToGrade(base_score, thresholds);

        // 3. 计算置信度
        const conf = calculateConfidence(coverage);

        // 4. 应用置信度 - 如果 < 60%，主评级 NR
        if (std.mem.eql(u8, conf.status, "nr")) {
            return RatingResult{
                .base_score = base_score,
                .base_grade = "NR",
                .redflag_grade = "NR",
                .shadow_grade = "NR",
                .published_grade = "NR", // PRD: NR可以发布，显示事实层和数据不足原因
                .confidence_six = conf.confidence,
                .redflags = try alloc.dupe(RedFlag, redflags),
                .compound_warning = false,
            };
        }

        // 5. 应用红牌
        const redflag_grade = applyRedFlags(base_grade, redflags);

        // 6. 影子档位（W1-W6 暂与 redflag_grade 相同）
        const shadow_grade = redflag_grade;

        // 7. 发布档位（W1-W6 = redflag_grade）
        const published_grade = redflag_grade;

        return RatingResult{
            .base_score = base_score,
            .base_grade = base_grade,
            .redflag_grade = redflag_grade,
            .shadow_grade = shadow_grade,
            .published_grade = published_grade,
            .confidence_six = conf.confidence,
            .redflags = try alloc.dupe(RedFlag, redflags),
            .compound_warning = false, // TODO: 三源启用后设置
        };
    }
};
