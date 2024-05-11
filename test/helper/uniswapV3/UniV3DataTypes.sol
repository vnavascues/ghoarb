// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library UniV3DataTypes {
    int24 internal constant MIN_TICK = -887_272;
    int24 internal constant MAX_TICK = -MIN_TICK;
    int24 internal constant TICK_SPACING = 60;

    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
}
