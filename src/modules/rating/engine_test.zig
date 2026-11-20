const std = @import("std");
const engine = @import("engine.zig");
const testing = std.testing;

test "评分引擎: 六维基础计算" {
    const alloc = testing.allocator;
    
    const weights = engine.DimensionWeights{
        .tech = 20,
        .team = 18,
        .tokenomics = 20,
        .community = 15,
        .liquidity = 15,
        .compliance = 12,
    };
    
    const scores = engine.SixDimensionScores{
        .tech = 85,
        .team = 90,
        .tokenomics = 80,
        .community = 75,
        .liquidity = 70,
        .compliance = 95,
    };
    
    const coverage = engine.CoverageSixDim{
        .tech = 100,
        .team = 100,
        .tokenomics = 100,
        .community = 100,
        .liquidity = 100,
        .compliance = 100,
    };
    
    const redflags: []const engine.RedFlag = &.{};
    
    const result = try engine.RatingEngine.calculateRating(
        alloc,
        scores,
        weights,
        coverage,
        redflags,
    );
    defer alloc.free(result.redflags);
    
    // 期望分数: 20*85 + 18*90 + 20*80 + 15*75 + 15*70 + 12*95 = 8185
    try testing.expectEqual(@as(i32, 8185), result.base_score);
    try testing.expectEqualStrings("A", result.base_grade);
    try testing.expectEqualStrings("A", result.published_grade);
}

test "评分引擎: NR档位可以发布" {
    const alloc = testing.allocator;
    
    const weights = engine.DimensionWeights{
        .tech = 20,
        .team = 18,
        .tokenomics = 20,
        .community = 15,
        .liquidity = 15,
        .compliance = 12,
    };
    
    const scores = engine.SixDimensionScores{
        .tech = 80,
        .team = 80,
        .tokenomics = 80,
        .community = 80,
        .liquidity = 80,
        .compliance = 80,
    };
    
    // 置信度不足60%触发NR
    const coverage = engine.CoverageSixDim{
        .tech = 50,
        .team = 50,
        .tokenomics = 50,
        .community = 50,
        .liquidity = 50,
        .compliance = 50,
    };
    
    const redflags: []const engine.RedFlag = &.{};
    
    const result = try engine.RatingEngine.calculateRating(
        alloc,
        scores,
        weights,
        coverage,
        redflags,
    );
    defer alloc.free(result.redflags);
    
    // NR档位必须可以发布（而非空字符串）
    try testing.expectEqualStrings("NR", result.base_grade);
    try testing.expectEqualStrings("NR", result.redflag_grade);
    try testing.expectEqualStrings("NR", result.published_grade);
    try testing.expect(result.confidence_six < 60);
}

test "评分引擎: 红牌规则不叠加降档" {
    const alloc = testing.allocator;
    
    const weights = engine.DimensionWeights{
        .tech = 20,
        .team = 18,
        .tokenomics = 20,
        .community = 15,
        .liquidity = 15,
        .compliance = 12,
    };
    
    // S档基础分数
    const scores = engine.SixDimensionScores{
        .tech = 95,
        .team = 95,
        .tokenomics = 95,
        .community = 95,
        .liquidity = 95,
        .compliance = 95,
    };
    
    const coverage = engine.CoverageSixDim{
        .tech = 100,
        .team = 100,
        .tokenomics = 100,
        .community = 100,
        .liquidity = 100,
        .compliance = 100,
    };
    
    // 两个普通红牌（R2和R3）
    const redflags = [_]engine.RedFlag{
        .{ .flag_id = "R2", .severity = "major", .description = "测试红牌1" },
        .{ .flag_id = "R3", .severity = "major", .description = "测试红牌2" },
    };
    
    const result = try engine.RatingEngine.calculateRating(
        alloc,
        scores,
        weights,
        coverage,
        &redflags,
    );
    defer alloc.free(result.redflags);
    
    // 基础档位应该是S
    try testing.expectEqualStrings("S", result.base_grade);
    
    // 两个普通红牌不叠加，最多降1档到A
    try testing.expectEqualStrings("A", result.redflag_grade);
    try testing.expectEqualStrings("A", result.published_grade);
}

test "评分引擎: R1和R4封顶D档" {
    const alloc = testing.allocator;
    
    const weights = engine.DimensionWeights{
        .tech = 20,
        .team = 18,
        .tokenomics = 20,
        .community = 15,
        .liquidity = 15,
        .compliance = 12,
    };
    
    // S档基础分数
    const scores = engine.SixDimensionScores{
        .tech = 95,
        .team = 95,
        .tokenomics = 95,
        .community = 95,
        .liquidity = 95,
        .compliance = 95,
    };
    
    const coverage = engine.CoverageSixDim{
        .tech = 100,
        .team = 100,
        .tokenomics = 100,
        .community = 100,
        .liquidity = 100,
        .compliance = 100,
    };
    
    // R1红牌（庞氏骗局）
    const redflags = [_]engine.RedFlag{
        .{ .flag_id = "R1", .severity = "critical", .description = "庞氏骗局特征" },
    };
    
    const result = try engine.RatingEngine.calculateRating(
        alloc,
        scores,
        weights,
        coverage,
        &redflags,
    );
    defer alloc.free(result.redflags);
    
    // 基础档位是S，但R1封顶D
    try testing.expectEqualStrings("S", result.base_grade);
    try testing.expectEqualStrings("D", result.redflag_grade);
    try testing.expectEqualStrings("D", result.published_grade);
}

test "评分引擎: 档位边界测试" {
    const alloc = testing.allocator;
    
    const weights = engine.DimensionWeights{
        .tech = 20,
        .team = 20,
        .tokenomics = 20,
        .community = 20,
        .liquidity = 10,
        .compliance = 10,
    };
    
    const coverage = engine.CoverageSixDim{
        .tech = 100,
        .team = 100,
        .tokenomics = 100,
        .community = 100,
        .liquidity = 100,
        .compliance = 100,
    };
    
    const redflags: []const engine.RedFlag = &.{};
    
    // 测试S档边界 (>=9000)
    {
        const scores = engine.SixDimensionScores{
            .tech = 90, .team = 90, .tokenomics = 90, 
            .community = 90, .liquidity = 90, .compliance = 90,
        };
        const result = try engine.RatingEngine.calculateRating(alloc, scores, weights, coverage, redflags);
        defer alloc.free(result.redflags);
        try testing.expectEqualStrings("S", result.base_grade);
    }
    
    // 测试A档边界 (>=8000)
    {
        const scores = engine.SixDimensionScores{
            .tech = 80, .team = 80, .tokenomics = 80,
            .community = 80, .liquidity = 80, .compliance = 80,
        };
        const result = try engine.RatingEngine.calculateRating(alloc, scores, weights, coverage, redflags);
        defer alloc.free(result.redflags);
        try testing.expectEqualStrings("A", result.base_grade);
    }
    
    // 测试B档边界 (>=6500)
    {
        const scores = engine.SixDimensionScores{
            .tech = 65, .team = 65, .tokenomics = 65,
            .community = 65, .liquidity = 65, .compliance = 65,
        };
        const result = try engine.RatingEngine.calculateRating(alloc, scores, weights, coverage, redflags);
        defer alloc.free(result.redflags);
        try testing.expectEqualStrings("B", result.base_grade);
    }
    
    // 测试C档边界 (>=5000)
    {
        const scores = engine.SixDimensionScores{
            .tech = 50, .team = 50, .tokenomics = 50,
            .community = 50, .liquidity = 50, .compliance = 50,
        };
        const result = try engine.RatingEngine.calculateRating(alloc, scores, weights, coverage, redflags);
        defer alloc.free(result.redflags);
        try testing.expectEqualStrings("C", result.base_grade);
    }
    
    // 测试D档 (<5000)
    {
        const scores = engine.SixDimensionScores{
            .tech = 40, .team = 40, .tokenomics = 40,
            .community = 40, .liquidity = 40, .compliance = 40,
        };
        const result = try engine.RatingEngine.calculateRating(alloc, scores, weights, coverage, redflags);
        defer alloc.free(result.redflags);
        try testing.expectEqualStrings("D", result.base_grade);
    }
}
