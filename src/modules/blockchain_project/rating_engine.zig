const std = @import("std");

/// 六维评分权重
pub const Weights = struct {
    c1_tech: f64,
    c2_team: f64,
    c3_token: f64,
    c4_product: f64,
    c5_community: f64,
    c6_governance: f64,
    
    pub fn validate(self: Weights) !void {
        const weights = [_]f64{ self.c1_tech, self.c2_team, self.c3_token, self.c4_product, self.c5_community, self.c6_governance };
        var sum: f64 = 0;
        for (weights) |w| {
            if (std.math.isNan(w) or w < 0 or w > 1) {
                return error.InvalidWeight;
            }
            sum += w;
        }
        if (@abs(sum - 1.0) > 0.001) {
            return error.WeightSumNotOne;
        }
    }
};

/// 六维原始分数
pub const DimensionScores = struct {
    c1_tech: ?f64,
    c2_team: ?f64,
    c3_token: ?f64,
    c4_product: ?f64,
    c5_community: ?f64,
    c6_governance: ?f64,
    
    pub fn validate(self: DimensionScores) !void {
        const scores = [_]?f64{ self.c1_tech, self.c2_team, self.c3_token, self.c4_product, self.c5_community, self.c6_governance };
        for (scores) |score_opt| {
            if (score_opt) |score| {
                if (std.math.isNan(score) or score < 0 or score > 100) {
                    return error.InvalidScore;
                }
            }
        }
    }
};

/// 红牌类型
pub const RedFlagType = enum {
    R1_critical_fraud,      // 封顶D
    R2_team_issue,          // 最多降一档
    R3_token_issue,         // 最多降一档
    R4_security_breach,     // 封顶D
    R5_regulatory_issue,    // 最多降一档
    R6_governance_failure,  // 最多降一档
};

/// 评级档位
pub const Grade = enum {
    S, A, B, C, D, NR,
    
    pub fn fromScore(score: f64, confidence: f64) Grade {
        // 低置信度优先返回NR
        if (confidence < 0.60) return .NR;
        
        if (score >= 85) return .S;
        if (score >= 75) return .A;
        if (score >= 60) return .B;
        if (score >= 45) return .C;
        return .D;
    }
    
    pub fn applyRedFlag(base_grade: Grade, flag_type: RedFlagType) Grade {
        return switch (flag_type) {
            .R1_critical_fraud, .R4_security_breach => .D,  // 封顶D
            .R2_team_issue, .R3_token_issue, .R5_regulatory_issue, .R6_governance_failure => {
                // 最多降一档，不跨D
                return switch (base_grade) {
                    .S => .A,
                    .A => .B,
                    .B => .C,
                    .C, .D => .D,  // C降为D，D保持D
                    .NR => .NR,
                };
            },
        };
    }
};

/// 评分结果
pub const RatingResult = struct {
    raw_total: f64,              // 原始加权总分
    base_grade: Grade,           // 基础档位
    redflag_grade: Grade,        // 应用红牌后档位
    published_grade: Grade,      // 最终发布档位（考虑影子降档）
    confidence: f64,             // 置信度
    confidence_numerator: f64,   // 置信度分子（有证据的维度权重和）
    confidence_denominator: f64, // 置信度分母（总权重）
};

/// 六维评分引擎
pub const RatingEngine = struct {
    weights: Weights,
    model_version: []const u8,
    
    pub fn init(weights: Weights, model_version: []const u8) !RatingEngine {
        try weights.validate();
        return .{
            .weights = weights,
            .model_version = model_version,
        };
    }
    
    pub fn calculate(
        self: RatingEngine,
        scores: DimensionScores,
        red_flags: []const RedFlagType,
        three_sources_insufficient: bool,
    ) !RatingResult {
        try scores.validate();
        
        // 计算加权总分和置信度
        const score_array = [_]?f64{ scores.c1_tech, scores.c2_team, scores.c3_token, scores.c4_product, scores.c5_community, scores.c6_governance };
        const weight_array = [_]f64{ self.weights.c1_tech, self.weights.c2_team, self.weights.c3_token, self.weights.c4_product, self.weights.c5_community, self.weights.c6_governance };
        
        var raw_total: f64 = 0;
        var confidence_numerator: f64 = 0;
        const confidence_denominator: f64 = 1.0;
        
        for (score_array, weight_array) |score_opt, weight| {
            if (score_opt) |score| {
                raw_total += score * weight;
                confidence_numerator += weight;
            }
        }
        
        const confidence = confidence_numerator / confidence_denominator;
        
        // 基础档位
        const base_grade = Grade.fromScore(raw_total, confidence);
        
        // 应用红牌
        var redflag_grade = base_grade;
        for (red_flags) |flag| {
            const downgraded = Grade.applyRedFlag(redflag_grade, flag);
            // 同时有多个红牌时，取最重的（最低的档位）
            if (@intFromEnum(downgraded) > @intFromEnum(redflag_grade)) {
                redflag_grade = downgraded;
            }
        }
        
        // 影子降档（三源不足）不改变published_grade
        const published_grade = redflag_grade;
        _ = three_sources_insufficient;  // 影子降档仅用于内部标记
        
        return RatingResult{
            .raw_total = raw_total,
            .base_grade = base_grade,
            .redflag_grade = redflag_grade,
            .published_grade = published_grade,
            .confidence = confidence,
            .confidence_numerator = confidence_numerator,
            .confidence_denominator = confidence_denominator,
        };
    }
};

// 测试
test "rating engine - S grade" {
    const weights = Weights{
        .c1_tech = 0.25,
        .c2_team = 0.20,
        .c3_token = 0.15,
        .c4_product = 0.20,
        .c5_community = 0.10,
        .c6_governance = 0.10,
    };
    
    const engine = try RatingEngine.init(weights, "v1.0");
    
    const scores = DimensionScores{
        .c1_tech = 90,
        .c2_team = 85,
        .c3_token = 88,
        .c4_product = 92,
        .c5_community = 80,
        .c6_governance = 85,
    };
    
    const result = try engine.calculate(scores, &.{}, false);
    
    try std.testing.expectEqual(Grade.S, result.base_grade);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.confidence, 0.001);
}

test "rating engine - low confidence NR" {
    const weights = Weights{
        .c1_tech = 0.50,
        .c2_team = 0.50,
        .c3_token = 0.0,
        .c4_product = 0.0,
        .c5_community = 0.0,
        .c6_governance = 0.0,
    };
    
    const engine = try RatingEngine.init(weights, "v1.0");
    
    const scores = DimensionScores{
        .c1_tech = 90,
        .c2_team = null,  // 缺失
        .c3_token = null,
        .c4_product = null,
        .c5_community = null,
        .c6_governance = null,
    };
    
    const result = try engine.calculate(scores, &.{}, false);
    
    // 置信度 = 0.5 / 1.0 = 0.5 < 0.60 → NR
    try std.testing.expectEqual(Grade.NR, result.base_grade);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result.confidence, 0.001);
}

test "rating engine - R1 caps to D" {
    const weights = Weights{
        .c1_tech = 1.0,
        .c2_team = 0.0,
        .c3_token = 0.0,
        .c4_product = 0.0,
        .c5_community = 0.0,
        .c6_governance = 0.0,
    };
    
    const engine = try RatingEngine.init(weights, "v1.0");
    
    const scores = DimensionScores{
        .c1_tech = 95,  // S级别
        .c2_team = null,
        .c3_token = null,
        .c4_product = null,
        .c5_community = null,
        .c6_governance = null,
    };
    
    const result = try engine.calculate(scores, &.{.R1_critical_fraud}, false);
    
    try std.testing.expectEqual(Grade.S, result.base_grade);
    try std.testing.expectEqual(Grade.D, result.redflag_grade);  // R1封顶D
}

test "rating engine - R2 downgrades one level" {
    const weights = Weights{
        .c1_tech = 1.0,
        .c2_team = 0.0,
        .c3_token = 0.0,
        .c4_product = 0.0,
        .c5_community = 0.0,
        .c6_governance = 0.0,
    };
    
    const engine = try RatingEngine.init(weights, "v1.0");
    
    const scores = DimensionScores{
        .c1_tech = 90,  // S级别
        .c2_team = null,
        .c3_token = null,
        .c4_product = null,
        .c5_community = null,
        .c6_governance = null,
    };
    
    const result = try engine.calculate(scores, &.{.R2_team_issue}, false);
    
    try std.testing.expectEqual(Grade.S, result.base_grade);
    try std.testing.expectEqual(Grade.A, result.redflag_grade);  // R2降一档 S→A
}

test "rating engine - invalid weight" {
    const weights = Weights{
        .c1_tech = 1.5,  // 超过1.0
        .c2_team = 0.0,
        .c3_token = 0.0,
        .c4_product = 0.0,
        .c5_community = 0.0,
        .c6_governance = 0.0,
    };
    
    try std.testing.expectError(error.InvalidWeight, RatingEngine.init(weights, "v1.0"));
}

test "rating engine - invalid score" {
    const weights = Weights{
        .c1_tech = 1.0,
        .c2_team = 0.0,
        .c3_token = 0.0,
        .c4_product = 0.0,
        .c5_community = 0.0,
        .c6_governance = 0.0,
    };
    
    const engine = try RatingEngine.init(weights, "v1.0");
    
    const scores = DimensionScores{
        .c1_tech = 150,  // 超过100
        .c2_team = null,
        .c3_token = null,
        .c4_product = null,
        .c5_community = null,
        .c6_governance = null,
    };
    
    try std.testing.expectError(error.InvalidScore, engine.calculate(scores, &.{}, false));
}
