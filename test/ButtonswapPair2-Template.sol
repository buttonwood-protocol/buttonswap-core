// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IButtonswapPairEvents, IButtonswapPairErrors} from "../src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair2} from "../src/ButtonswapPair2.sol";
import {Math} from "../src/libraries/Math.sol";
import {PairMath2} from "../src/libraries/PairMath2.sol";
import {MockERC20} from "mock-contracts/MockERC20.sol";
import {ICommonMockRebasingERC20} from "mock-contracts/interfaces/ICommonMockRebasingERC20/ICommonMockRebasingERC20.sol";
import {MockButtonswapFactory} from "./mocks/MockButtonswapFactory2.sol";
import {MockButtonswapPair2} from "./mocks/MockButtonswapPair2.sol";
import {Utils} from "./utils/Utils.sol";
import {PriceAssertion} from "./utils/PriceAssertion.sol";
import {UQ112x112} from "../src/libraries/UQ112x112.sol";

// This defines the tests but this contract is abstract because multiple implementations using different rebasing token types run them
abstract contract ButtonswapPair2Test is Test, IButtonswapPairEvents, IButtonswapPairErrors {
    struct TestVariables {
        address zeroAddress;
        address feeToSetter;
        address feeTo;
        address minter1;
        address minter2;
        address swapper1;
        address swapper2;
        address receiver;
        address burner1;
        address burner2;
        address exploiter;
        MockButtonswapFactory factory;
        ButtonswapPair2 pair;
        MockERC20 token0;
        MockERC20 token1;
        ICommonMockRebasingERC20 rebasingToken0;
        ICommonMockRebasingERC20 rebasingToken1;
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 liquidity1;
        uint256 liquidity2;
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
    }

    MockERC20 public tokenA;
    MockERC20 public tokenB;
    ICommonMockRebasingERC20 public rebasingTokenA;
    ICommonMockRebasingERC20 public rebasingTokenB;
    address public userA = 0x000000000000000000000000000000000000000A;
    address public userB = 0x000000000000000000000000000000000000000b;
    address public userC = 0x000000000000000000000000000000000000000C;
    address public userD = 0x000000000000000000000000000000000000000d;
    address public userE = 0x000000000000000000000000000000000000000E;

    function getTokenA() public virtual returns (MockERC20) {
        return new MockERC20("TokenA", "TKNA");
    }

    function getTokenB() public virtual returns (MockERC20) {
        return new MockERC20("TokenB", "TKNB");
    }

    function getRebasingTokenA() public virtual returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(0));
    }

    function getRebasingTokenB() public virtual returns (ICommonMockRebasingERC20) {
        return ICommonMockRebasingERC20(address(0));
    }

    function setUp() public {
        tokenA = getTokenA();
        tokenA.initialize();
        tokenB = getTokenB();
        tokenB.initialize();
        rebasingTokenA = getRebasingTokenA();
        rebasingTokenA.initialize();
        rebasingTokenB = getRebasingTokenB();
        rebasingTokenB.initialize();
    }

    function test_initialize(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair2 pair = new ButtonswapPair2();

        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));

        vm.prank(factory);
        pair.initialize(token0, token1);
        assertEq(pair.token0(), token0);
        assertEq(pair.token1(), token1);
        assertEq(pair.totalSupply(), 0);
        assertEq(pair.balanceOf(address(0)), 0);
        assertEq(pair.balanceOf(factory), 0);
    }

    function test_initialize_CannotCallWhenNotCreator(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair2 pair = new ButtonswapPair2();

        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(0));
        assertEq(pair.token1(), address(0));

        vm.expectRevert(Forbidden.selector);
        pair.initialize(token0, token1);
    }

    function test_initialize_CreateViaFactory(address token0, address token1) public {
        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(token0, token1));

        assertEq(vars.pair.token0(), token0);
        assertEq(vars.pair.token1(), token1);
        assertEq(vars.pair.totalSupply(), 0);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 0);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
    }

    function test_getLiquidityBalances_ReturnsZeroBeforeFirstMint(address factory) public {
        vm.assume(factory != address(this));

        vm.startPrank(factory);
        ButtonswapPair2 pair = new ButtonswapPair2();
        pair.initialize(address(tokenA), address(tokenB));
        vm.stopPrank();

        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1, uint256 blockTimestampLast) =
            pair.getLiquidityBalances();
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        assertEq(blockTimestampLast, 0);
    }

    function test_getLiquidityBalances(uint112 _pool0Last, uint112 _pool1Last, uint112 total0, uint112 total1) public {
        vm.assume(_pool0Last != 0 && _pool1Last != 0);
        vm.assume(total0 != 0 && total1 != 0);
        MockButtonswapPair2 pair = new MockButtonswapPair2();
        pair.mockSetPoolsLast(_pool0Last, _pool1Last);
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) =
            pair.mockGetLiquidityBalances(uint256(total0), uint256(total1));
        assertEq(pool0 + reservoir0, total0, "token0 liquidity balances don't sum to total");
        assertEq(pool1 + reservoir1, total1, "token1 liquidity balances don't sum to total");
        assertTrue(reservoir0 == 0 || reservoir1 == 0, "Both reservoirs are non-zero");
        if (pool0 == 0) {
            assertEq((pool1 * _pool0Last) / _pool1Last, 0, "pool0 should not be zero");
        } else if (pool1 == 0) {
            assertEq((pool0 * _pool1Last) / _pool0Last, 0, "pool1 should not be zero");
        } else {
            assertEq(
                PriceAssertion.isPriceUnchanged256(reservoir0, reservoir1, _pool0Last, _pool1Last, pool0, pool1),
                true,
                "New price outside of tolerance"
            );
        }
    }

    function test_getLiquidityBalances_ReturnsZeroWhenEitherTotalIsZero(
        uint112 _pool0Last,
        uint112 _pool1Last,
        uint256 total0,
        uint256 total1
    ) public {
        vm.assume(_pool0Last != 0 && _pool1Last != 0);
        MockButtonswapPair2 pair = new MockButtonswapPair2();
        pair.mockSetPoolsLast(_pool0Last, _pool1Last);
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
        (pool0, pool1, reservoir0, reservoir1) = pair.mockGetLiquidityBalances(0, total1);
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        (pool0, pool1, reservoir0, reservoir1) = pair.mockGetLiquidityBalances(total0, 0);
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        (pool0, pool1, reservoir0, reservoir1) = pair.mockGetLiquidityBalances(0, 0);
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
    }

    function test_mint_FirstMint(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount0 * amount1) > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount0);
        vars.token1.approve(address(vars.pair), amount1);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter1, amount0, amount1);
        uint256 liquidity1 = vars.pair.mint(amount0, amount1, vars.minter1);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), liquidity1 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), liquidity1);
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(pool0, amount0);
        assertEq(pool1, amount1);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        assertEq(liquidity1, Math.sqrt(amount0 * amount1) - 1000);
    }

    function test_mint_NonRebasingSecondMint(uint256 amount00, uint256 amount01) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 to make room for the second mint
        vm.assume(amount00 < (2 ** 112) / 4);
        vm.assume(amount01 < (2 ** 112) / 4);
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Second mint needs to match same ratio as first mint
        uint256 amount10 = amount00 * 3;
        uint256 amount11 = amount01 * 3;

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        uint256 pool0Previous = amount00;
        uint256 pool1Previous = amount01;
        // Calculate expected values to assert against
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        uint256 liquidityNew = PairMath2.getDualSidedMintLiquidityOutAmount(
            vars.pair.totalSupply(), amount10, amount11, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        vm.assume(liquidityNew > 0);

        vm.startPrank(vars.minter2);
        vars.token0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000, "totalSupply");
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged256(
                vars.reservoir0, vars.reservoir1, pool0Previous, pool1Previous, vars.pool0, vars.pool1
            ),
            true,
            "New price outside of tolerance"
        );
    }

    function test_mint_CannotMintWithUnequalAmounts(
        uint256 amount00,
        uint256 amount01,
        uint256 amount10,
        uint256 amount11
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by two to make room for second mint
        vm.assume(amount00 < (2 ** 112) / 2);
        vm.assume(amount01 < (2 ** 112) / 2);
        vm.assume(amount10 < (2 ** 112) / 2);
        vm.assume(amount11 < (2 ** 112) / 2);
        // Amounts must be non-zero
        vm.assume(amount10 > 0);
        vm.assume(amount11 > 0);
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Second mint must not match price ratio
        vm.assume(amount11 != ((amount10 * amount01) / amount00));

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectRevert(UnequalMint.selector);
        vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();
    }

    function test_mint_CannotFirstMintWithInsufficientLiquidity(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        // They must also be insufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        // Use bound to avoid hitting reject cap
        uint256 min = 999 ** 2;
        uint256 max = 1001 ** 2;
        amount0 = bound(amount0, min, max);
        amount1 = bound(amount1, min / amount0, max / amount0);
        vm.assume(Math.sqrt(amount0 * amount1) == 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount0);
        vars.token1.approve(address(vars.pair), amount1);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(amount0, amount1, vars.minter1);
        vm.stopPrank();
    }

    function test_mint_CannotFirstMintWithBelowMinimumLiquidity(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(amount0 < (2 ** 112));
        vm.assume(amount1 < (2 ** 112));
        // Amounts must be non-zero
        vm.assume(amount0 > 0);
        vm.assume(amount1 > 0);
        // They must also be insufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount0 * amount1) < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount0);
        vars.token1.approve(address(vars.pair), amount1);
        vm.expectRevert(stdError.arithmeticError);
        vars.pair.mint(amount0, amount1, vars.minter1);
        vm.stopPrank();
    }

    function test_mint_CannotSecondMintWithInsufficientLiquidity(uint256 amount00, uint256 amount01) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by two to make room for second mint
        vm.assume(amount00 < (2 ** 112) / 2);
        vm.assume(amount01 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(amount00 > 1000);
        vm.assume(amount01 > 1000);

        // Calculate the smallest second mint possible that doesn't violate price ratio
        uint256 amount10 = 1;
        uint256 amount11 = 1;
        if (amount00 < amount01) {
            amount11 = amount01 / amount00;
        } else {
            amount10 = amount00 / amount01;
        }

        // Filter for scenarios where we expect the new liquidity to dip below 1, to check the error
        vm.assume(((Math.sqrt(amount00 * amount01) * (amount11 + amount11)) / (amount01 + amount01)) == 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();
    }

    function test_mint_PartialRebasingSecondMint(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        uint256 pool0Previous = amount00;
        uint256 pool1Previous = amount01;
        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        uint256 liquidityNew = PairMath2.getDualSidedMintLiquidityOutAmount(
            vars.pair.totalSupply(), amount10, amount11, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged256(
                vars.reservoir0, vars.reservoir1, pool0Previous, pool1Previous, vars.pool0, vars.pool1
            ),
            true,
            "New price outside of tolerance"
        );
    }

    function test_mint_PartialRebasingSecondMintDebug() public {
        uint256 amount00 = 4385529531185;
        uint256 amount01 = 1;
        uint256 rebaseNumerator = 3;
        uint256 rebaseDenominator = 2;

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        uint256 pool0Previous = amount00;
        uint256 pool1Previous = amount01;
        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        uint256 liquidityNew = PairMath2.getDualSidedMintLiquidityOutAmount(
            vars.pair.totalSupply(), amount10, amount11, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged256(
                vars.reservoir0, vars.reservoir1, pool0Previous, pool1Previous, vars.pool0, vars.pool1
            ),
            true,
            "New price outside of tolerance"
        );
    }

    function test_mint_FullRebasingSecondMint(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 4 so that it can handle a second mint
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / (4 * 1000)));
        vm.assume(amount01 < (uint256(2 ** 112) / (4 * 1000)));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount01 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.rebasingToken1.mint(vars.minter1, amount01);

        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.rebasingToken1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        uint256 pool0Previous = amount00;
        uint256 pool1Previous = amount01;
        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);

        // Second mint needs to match new price ratio
        uint256 amount10 = vars.pool0 * 3;
        uint256 amount11 = vars.pool1 * 3;
        vm.assume(amount10 < vars.rebasingToken0.mintableBalance());
        vm.assume(amount11 < vars.rebasingToken1.mintableBalance());
        vars.rebasingToken0.mint(vars.minter2, amount10);
        vars.rebasingToken1.mint(vars.minter2, amount11);

        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        uint256 liquidityNew = PairMath2.getDualSidedMintLiquidityOutAmount(
            vars.pair.totalSupply(), amount10, amount11, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        vm.assume(liquidityNew > 0);

        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.rebasingToken1.approve(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mint(amount10, amount11, vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000, "totalSupply");
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged256(
                vars.reservoir0, vars.reservoir1, pool0Previous, pool1Previous, vars.pool0, vars.pool1
            ),
            true,
            "New price outside of tolerance"
        );
    }

    /// @param amount1X The amount for the second mint, with it not yet known which token it corresponds to
    function test_mintWithReservoir(
        uint256 amount00,
        uint256 amount01,
        uint256 amount1X,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        uint256 amount10;
        uint256 amount11;
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / 1000));
        vm.assume(amount01 < (uint256(2 ** 112) / 1000));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        uint256 pool0Previous = amount00;
        uint256 pool1Previous = amount01;
        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);

        uint256 liquidityNew;
        // Prepare the appropriate token for the second mint based on which reservoir has a non-zero balance
        if (vars.reservoir0 > 0) {
            uint256 reservoir0InTermsOf1 = (vars.reservoir0 * vars.pool1) / vars.pool0;
            // Ensure we don't try to mint more than there's reservoir funds to pair with
            vm.assume(amount1X <= reservoir0InTermsOf1);
            amount11 = amount1X;
            vars.token1.mint(vars.minter2, amount1X);
            // Calculate the liquidity the minter should receive
            liquidityNew = PairMath2.getSingleSidedMintLiquidityOutAmount(
                vars.pair.totalSupply(), amount11, vars.pool0, vars.pool1, vars.reservoir0
            );
        } else {
            uint256 reservoir1InTermsOf0 = (vars.reservoir1 * vars.pool0) / vars.pool1;
            // Ensure we don't try to mint more than there's reservoir funds to pair with
            vm.assume(amount1X <= reservoir1InTermsOf0);
            vm.assume(amount1X < vars.rebasingToken0.mintableBalance());
            amount10 = amount1X;
            vars.rebasingToken0.mint(vars.minter2, amount1X);
            // Calculate the liquidity the minter should receive
            liquidityNew = PairMath2.getSingleSidedMintLiquidityOutAmount(
                vars.pair.totalSupply(), amount10, vars.pool1, vars.pool0, vars.reservoir1
            );
        }
        // Ignore cases where no new liquidity is created
        vm.assume(liquidityNew > 0);

        // Do mint with reservoir
        vm.startPrank(vars.minter2);
        // Whilst we are approving both tokens, in practise one of these amounts will be zero
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        vars.liquidity2 = vars.pair.mintWithReservoir(amount1X, vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), vars.liquidity1 + vars.liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        // There should be no fee collected on balance increases that occur outside of a swap
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), vars.liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), vars.liquidity2);
        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        assertEq(vars.liquidity2, liquidityNew, "liquidity2");
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged256(
                vars.reservoir0, vars.reservoir1, pool0Previous, pool1Previous, vars.pool0, vars.pool1
            ),
            true,
            "New price outside of tolerance"
        );
    }

    /// @dev Test that the method reverts if the token amounts deposited are zero
    function test_mintWithReservoir_CannotMintWithInsufficientLiquidityAdded(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Keep these as zero
        uint256 amount10;
        uint256 amount11;
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / 1000));
        vm.assume(amount01 < (uint256(2 ** 112) / 1000));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);

        // Attempt mintWithReservoir with both amounts set to zero
        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectRevert(InsufficientLiquidityAdded.selector);
        // Pass in zero
        vars.pair.mintWithReservoir(0, vars.minter2);
        vm.stopPrank();
    }

    function test_mintWithReservoir_CannotMintWhenUninitialized(uint256 amount0, uint256 amount1) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount0 < (uint256(2 ** 112) / 1000));
        vm.assume(amount1 < (uint256(2 ** 112) / 1000));
        // One amount must be zero
        vm.assume((amount0 == 0 && amount1 != 0) || (amount0 != 0 && amount1 == 0));

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount0 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        // Attempting mintWithReservoir as the first mint
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount0);
        vars.token1.approve(address(vars.pair), amount1);
        vm.expectRevert(Uninitialized.selector);
        // Amount just needs to be non-zero
        vars.pair.mintWithReservoir(1, vars.minter1);
        vm.stopPrank();
    }

    /// @param amount1X The amount for the second mint, with it not yet known which token it corresponds to
    function test_mintWithReservoir_CannotMintWithInsufficientReservoir(
        uint256 amount00,
        uint256 amount01,
        uint256 amount1X,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        uint256 amount10;
        uint256 amount11;
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / 1000));
        vm.assume(amount01 < (uint256(2 ** 112) / 1000));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);

        // Prepare the appropriate token for the second mint based on which reservoir has a non-zero balance
        if (vars.reservoir0 > 0) {
            uint256 reservoir0InTermsOf1 = (vars.reservoir0 * vars.pool1) / vars.pool0;
            // Ensure we mint more than there's reservoir funds to pair with
            // +1 because due to rounding sometimes the test fails otherwise (amount1X is equal to the reservoir instead)
            vm.assume(amount1X > reservoir0InTermsOf1 + 1);
            // Ensure we don't get math overflow errors
            vm.assume(amount1X < type(uint256).max / (vars.pool0 * vars.pair.totalSupply()));
            amount11 = amount1X;
            vars.token1.mint(vars.minter2, amount1X);
        } else {
            uint256 reservoir1InTermsOf0 = (vars.reservoir1 * vars.pool0) / vars.pool1;
            // Ensure we mint more than there's reservoir funds to pair with
            // +1 because due to rounding sometimes the test fails otherwise (amount1X is equal to the reservoir instead)
            vm.assume(amount1X > reservoir1InTermsOf0 + 1);
            // Ensure we don't get math overflow errors
            vm.assume(amount1X < type(uint256).max / (vars.pool1 * vars.pair.totalSupply()));
            vm.assume(amount1X < vars.rebasingToken0.mintableBalance());
            amount10 = amount1X;
            vars.rebasingToken0.mint(vars.minter2, amount1X);
        }

        // Attempt mint with reservoir
        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectRevert(InsufficientReservoir.selector);
        vars.pair.mintWithReservoir(amount1X, vars.minter2);
        vm.stopPrank();
    }

    /// @dev Test that the method reverts if the amount of liquidity tokens the user receives is calculated to be zero
    function test_mintWithReservoir_CannotMintWithInsufficientLiquidityMinted(
        uint256 amount00,
        uint256 amount01,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Hardcode to smallest value as fuzzer hits retry limit otherwise
        uint256 amount1X = 1;
        uint256 amount10;
        uint256 amount11;
        // Make sure the amounts aren't liable to overflow 2**112
        // Divide by 1000 so that it can handle a rebase
        vm.assume(amount00 < (uint256(2 ** 112) / 1000));
        vm.assume(amount01 < (uint256(2 ** 112) / 1000));
        // Amounts must be non-zero
        // They must also be sufficient for equivalent liquidity to exceed the MINIMUM_LIQUIDITY
        vm.assume(Math.sqrt(amount00 * amount01) > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator = bound(rebaseNumerator, 1, 1000);
        rebaseDenominator = bound(rebaseDenominator, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.minter2 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(amount00 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.approve(address(vars.pair), amount00);
        vars.token1.approve(address(vars.pair), amount01);
        vars.liquidity1 = vars.pair.mint(amount00, amount01, vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        (vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1,) = vars.pair.getLiquidityBalances();
        // Ignore edge cases where negative rebase removes all liquidity
        vm.assume(vars.pool0 > 0 && vars.pool1 > 0);
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);

        // Calculate expected values to assert against
        uint256 liquidityNew;

        // Prepare the appropriate token for the second mint based on which reservoir has a non-zero balance
        if (vars.reservoir0 > 0) {
            uint256 reservoir0InTermsOf1 = (vars.reservoir0 * vars.pool1) / vars.pool0;
            // Ensure we don't try to mint more than there's reservoir funds to pair with
            vm.assume(amount1X <= reservoir0InTermsOf1);
            amount11 = amount1X;
            vars.token1.mint(vars.minter2, amount1X);
            // Calculate the liquidity the minter should receive
            liquidityNew = PairMath2.getSingleSidedMintLiquidityOutAmount(
                vars.pair.totalSupply(), amount11, vars.pool0, vars.pool1, vars.reservoir0
            );
        } else {
            uint256 reservoir1InTermsOf0 = (vars.reservoir1 * vars.pool0) / vars.pool1;
            // Ensure we don't try to mint more than there's reservoir funds to pair with
            vm.assume(amount1X <= reservoir1InTermsOf0);
            vm.assume(amount1X < vars.rebasingToken0.mintableBalance());
            amount10 = amount1X;
            vars.rebasingToken0.mint(vars.minter2, amount1X);
            // Calculate the liquidity the minter should receive
            liquidityNew = PairMath2.getSingleSidedMintLiquidityOutAmount(
                vars.pair.totalSupply(), amount10, vars.pool1, vars.pool0, vars.reservoir1
            );
        }
        // Ignore cases where no new liquidity is created
        vm.assume(liquidityNew == 0);
        // amount1X must be non-zero though to test this specific error
        vm.assume(amount1X > 0);

        // Attempt mint with reservoir
        vm.startPrank(vars.minter2);
        vars.rebasingToken0.approve(address(vars.pair), amount10);
        vars.token1.approve(address(vars.pair), amount11);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mintWithReservoir(amount1X, vars.minter2);
        vm.stopPrank();
    }

    // TODO progress cutoff point

    function test_burn(uint256 mintAmount0, uint256 mintAmount1, uint256 burnAmount) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        vm.assume(burnAmount > 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // burnAmount must not exceed amount of liquidity tokens minter has
        vm.assume(burnAmount <= vars.pair.balanceOf(vars.minter1));
        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 expectedTotalSupply = vars.pair.totalSupply() - burnAmount;
        (uint256 expectedAmount0, uint256 expectedAmount1) = PairMath.getDualSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmount, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // Ignore edge cases where both expected amounts are zero
        vm.assume(expectedAmount0 > 0 && expectedAmount1 > 0);

        // Do burn
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(vars.minter1, expectedAmount0, expectedAmount1, vars.receiver);
        (uint256 amount0, uint256 amount1) = vars.pair.burn(vars.receiver);
        vm.stopPrank();

        // Confirm state as expected
        assertEq(amount0, expectedAmount0);
        assertEq(amount1, expectedAmount1);
        assertEq(vars.token0.balanceOf(vars.receiver), expectedAmount0);
        assertEq(vars.token1.balanceOf(vars.receiver), expectedAmount1);
        assertEq(vars.pair.totalSupply(), expectedTotalSupply);
    }

    function test_burn_CannotCallWithInsufficientLiquidityBurned(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // burnAmount must not exceed amount of liquidity tokens minter has
        vm.assume(burnAmount <= vars.pair.balanceOf(vars.minter1));
        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        (uint256 expectedAmount0, uint256 expectedAmount1) = PairMath.getDualSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmount, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // Target edge cases where one or both expected amounts are zero
        vm.assume(expectedAmount0 == 0 || expectedAmount1 == 0);

        // Attempt burn
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectRevert(InsufficientLiquidityBurned.selector);
        vars.pair.burn(vars.receiver);
        vm.stopPrank();
    }

    function test_burnFromReservoir(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        vm.assume(burnAmount > 0);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Sync
        vars.pair.sync();

        // burnAmount must not exceed amount of liquidity tokens minter has
        vm.assume(burnAmount <= vars.pair.balanceOf(vars.minter1));
        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        uint256 expectedTotalSupply = vars.pair.totalSupply() - burnAmount;
        (uint256 expectedAmount0, uint256 expectedAmount1) = PairMath.getSingleSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmount, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // Ignore edge cases where both expected amounts are zero
        vm.assume(expectedAmount0 > 0 || expectedAmount1 > 0);
        // Ignore cases where expected amount exceeds reservoir balances
        vm.assume(expectedAmount0 <= vars.reservoir0 && expectedAmount1 <= vars.reservoir1);

        // Do burnFromReservoir
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(vars.minter1, expectedAmount0, expectedAmount1, vars.receiver);
        (uint256 amount0, uint256 amount1) = vars.pair.burnFromReservoir(vars.receiver);
        vm.stopPrank();

        // Confirm state as expected
        assertEq(amount0, expectedAmount0);
        assertEq(amount1, expectedAmount1);
        assertEq(vars.rebasingToken0.balanceOf(vars.receiver), expectedAmount0);
        assertEq(vars.token1.balanceOf(vars.receiver), expectedAmount1);
        assertEq(vars.pair.totalSupply(), expectedTotalSupply);
    }

    /// @dev The approach here is a little more obtuse that normal.
    /// This is due to repeated `vm.assume`s causing it to run out of retry attempts.
    /// Liberal use of `bound` gets around this issue.
    function test_burnFromReservoir_CannotCallWhenInsufficientLiquidityBurned(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator = bound(rebaseNumerator, 1, 1000);
        rebaseDenominator = bound(rebaseDenominator, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Sync
        vars.pair.sync();

        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);
        // Start with full possible burnAmount
        uint256 burnAmountMax = vars.pair.balanceOf(vars.minter1);
        uint256 expectedAmount0;
        uint256 expectedAmount1;
        // Estimate redeemed amounts if full balance was burned
        (expectedAmount0, expectedAmount1) = PairMath.getSingleSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmountMax, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // Divide the max by expected amount, +1 to ensure that it always divides to zero
        if (expectedAmount0 > 0) {
            burnAmountMax = burnAmountMax / (expectedAmount0 + 1);
        } else if (expectedAmount1 > 0) {
            burnAmountMax = burnAmountMax / (expectedAmount1 + 1);
        }
        // We don't want to test the trivial case where burnAmount is zero
        vm.assume(burnAmountMax > 0);
        // Scale the random burnAmount to be within valid range
        burnAmount = bound(burnAmount, 1, burnAmountMax);
        // Update estimate redeemed amounts with adjusted burnAmount
        (expectedAmount0, expectedAmount1) = PairMath.getSingleSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmount, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // This should result in  both expected amounts being zero
        vm.assume(expectedAmount0 == 0 && expectedAmount1 == 0);
        // Ignore cases where expected amount exceeds reservoir balances
        vm.assume(expectedAmount0 <= vars.reservoir0 && expectedAmount1 <= vars.reservoir1);

        // Attempt burnFromReservoir
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectRevert(InsufficientLiquidityBurned.selector);
        vars.pair.burnFromReservoir(vars.receiver);
        vm.stopPrank();
    }

    function test_burnFromReservoir_CannotCallWhenBothReservoirsAreEmpty(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(burnAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        vm.assume(burnAmount > 0);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // burnAmount must not exceed amount of liquidity tokens minter has
        vm.assume(burnAmount <= vars.pair.balanceOf(vars.minter1));

        // Attempt burnFromReservoir
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectRevert(InsufficientLiquidityBurned.selector);
        vars.pair.burnFromReservoir(vars.receiver);
        vm.stopPrank();
    }

    function test_burnFromReservoir_CannotCallWhenInsufficientReservoir(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 burnAmount,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator = bound(rebaseNumerator, 1, 1000);
        rebaseDenominator = bound(rebaseDenominator, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.receiver = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 < vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);
        // Sync
        vars.pair.sync();

        // Scale the random burnAmount to be within valid range
        // burnAmount must not exceed amount of liquidity tokens minter has
        burnAmount = bound(burnAmount, 1, vars.pair.balanceOf(vars.minter1));
        // Calculate expected values to assert against
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        (vars.reservoir0, vars.reservoir1) = vars.pair.getReservoirs();
        // Ignore edge cases where both reservoirs are still 0
        vm.assume(vars.reservoir0 > 0 || vars.reservoir1 > 0);
        (uint256 expectedAmount0, uint256 expectedAmount1) = PairMath.getSingleSidedBurnOutputAmounts(
            vars.pair.totalSupply(), burnAmount, vars.pool0, vars.pool1, vars.reservoir0, vars.reservoir1
        );
        // Ignore edge cases where both expected amounts are zero
        vm.assume(expectedAmount0 > 0 || expectedAmount1 > 0);
        // Target cases where expected amount exceeds reservoir balances
        vm.assume(expectedAmount0 > vars.reservoir0 || expectedAmount1 > vars.reservoir1);

        // Attempt burnFromReservoir
        vm.startPrank(vars.minter1);
        vars.pair.transfer(address(vars.pair), burnAmount);
        vm.expectRevert(InsufficientReservoir.selector);
        vars.pair.burnFromReservoir(vars.receiver);
        vm.stopPrank();
    }

    function test_swap(uint256 mintAmount0, uint256 mintAmount1, uint256 inputAmount, bool inputToken0) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(inputAmount < mintAmount0 && inputAmount < mintAmount1);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount1, mintAmount0);
            vm.assume(vars.amount0Out > 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Do the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectEmit(true, true, true, true);
        emit Swap(vars.swapper1, vars.amount0In, vars.amount1In, vars.amount0Out, vars.amount1Out, vars.receiver);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();

        // Confirm new state is as expected
        assertEq(vars.token0.balanceOf(address(vars.pair)), mintAmount0 + vars.amount0In - vars.amount0Out);
        assertEq(vars.token0.balanceOf(vars.swapper1), 0);
        assertEq(vars.token0.balanceOf(vars.receiver), vars.amount0Out);
        assertEq(vars.token1.balanceOf(address(vars.pair)), mintAmount1 + vars.amount1In - vars.amount1Out);
        assertEq(vars.token1.balanceOf(vars.swapper1), 0);
        assertEq(vars.token1.balanceOf(vars.receiver), vars.amount1Out);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
        assertEq(pool0, mintAmount0 + vars.amount0In - vars.amount0Out);
        assertEq(pool1, mintAmount1 + vars.amount1In - vars.amount1Out);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
    }

    function test_swap_CannotSwapWithInsufficientOutputAmount(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 inputAmount,
        bool inputToken0
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(inputAmount < mintAmount0 && inputAmount < mintAmount1);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be zero
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out == 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount1, mintAmount0);
            vm.assume(vars.amount0Out == 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InsufficientOutputAmount.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    function test_swap_CannotSwapForMoreOutputTokensThanInPool(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 outputAmount,
        bool inputToken0
    ) public {
        // This test is a bit weird, as if you calculate an outputAmount that won't violate the K invariant then you can never hit the error this checks for

        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(outputAmount < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be greater than pool liquidity
        if (inputToken0) {
            vars.amount1Out = outputAmount;
            vm.assume(vars.amount1Out >= mintAmount1);
        } else {
            vars.amount0Out = outputAmount;
            vm.assume(vars.amount0Out >= mintAmount0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InsufficientLiquidity.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    /// @dev Can't specify the recipient as the address of either of the pool tokens
    function test_swap_CannotSwapWithInvalidRecipient(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 inputAmount,
        bool receiverToken0
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(inputAmount < mintAmount0 && inputAmount < mintAmount1);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        vars.amount0In = inputAmount;
        vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1);
        vm.assume(vars.amount1Out > 0);

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        // Set receiver to invalid value
        if (receiverToken0) {
            vars.receiver = vars.pair.token0();
        } else {
            vars.receiver = vars.pair.token1();
        }
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InvalidRecipient.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    /// @param inputToken0 Whether token0 should be used as the input token for the swap
    function test_swap_CannotSwapWithInsufficientInputAmount(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 inputAmount,
        bool inputToken0
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(inputAmount < mintAmount0 && inputAmount < mintAmount1);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount1, mintAmount0);
            vm.assume(vars.amount0Out > 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        // Don't transfer any tokens in
        vm.expectRevert(InsufficientInputAmount.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    function test_swap_CannotSwapWhenFinalKValueIsInvalid(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 inputAmount,
        bool inputToken0
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        vm.assume(inputAmount < mintAmount0 && inputAmount < mintAmount1);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        vm.assume(inputAmount > 0);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        // Add 1 to calculated output amount to test K invariant prevents transaction
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1) + 1;
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount1, mintAmount0) + 1;
            vm.assume(vars.amount0Out > 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(KInvariant.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    function test_sync_CannotSyncBeforeFirstMint(address syncer) public {
        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));

        // Attempt sync
        vm.prank(syncer);
        vm.expectRevert(Uninitialized.selector);
        vars.pair.sync();
    }

    function test_sync_NonRebasing(uint256 mintAmount0, uint256 mintAmount1, address syncer) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Store current state for later comparison
        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Do sync
        vm.prank(syncer);
        // Expect no changes since there's no rebasing
        vm.expectEmit(true, true, true, true);
        emit SyncReservoir(uint112(reservoir0), uint112(reservoir1));
        vars.pair.sync();

        // Confirm final state meets expectations
        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1),
            true,
            "New price outside of tolerance"
        );
    }

    function test_sync_PartialRebasing(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        vm.assume(rebaseNumerator > 0 && rebaseNumerator < 1000);
        vm.assume(rebaseDenominator > 0 && rebaseDenominator < 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Store current state for later comparison
        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator, rebaseDenominator);

        // Do sync
        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        // Confirm final state meets expectations
        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1),
            true,
            "New price outside of tolerance"
        );
    }

    function test_sync_FullRebasingAfterNonEmptyReservoir(
        uint256 mintAmount0,
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator0,
        uint256 rebaseDenominator0,
        uint256 rebaseNumerator1,
        uint256 rebaseDenominator1
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 111));
        vm.assume(mintAmount1 < (2 ** 111));
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator0 = bound(rebaseNumerator0, 1, 1000);
        rebaseDenominator0 = bound(rebaseDenominator0, 1, 1000);
        rebaseNumerator1 = bound(rebaseNumerator1, 1, 1000);
        rebaseDenominator1 = bound(rebaseDenominator1, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(rebasingTokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.rebasingToken1 = ICommonMockRebasingERC20(vars.pair.token1());
        vm.assume(mintAmount0 <= vars.rebasingToken0.mintableBalance());
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vm.assume(mintAmount1 <= vars.rebasingToken1.mintableBalance());
        vars.rebasingToken1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.rebasingToken1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Apply first rebase
        vars.rebasingToken0.applyMultiplier(rebaseNumerator0, rebaseDenominator0);

        // Do first sync
        vm.prank(syncer);
        vars.pair.sync();

        // One reservoir should be non-zero now
        (uint112 pool0, uint112 pool1,) = vars.pair.getPools();
        (uint112 reservoir0, uint112 reservoir1) = vars.pair.getReservoirs();
        // Filter out fuzzed input that didn't rebase
        vm.assume(reservoir0 != 0 || reservoir1 != 0);
        uint112 pool0Previous = pool0;
        uint112 pool1Previous = pool1;

        // Apply second rebase
        vars.rebasingToken1.applyMultiplier(rebaseNumerator1, rebaseDenominator1);

        // Do second sync starting from non-empty reservoir state
        vm.prank(syncer);
        // Predicting final pool and reservoir values is too complex to test
        vm.expectEmit(false, false, false, false);
        emit Sync(0, 0);
        vm.expectEmit(false, false, false, false);
        emit SyncReservoir(0, 0);
        vars.pair.sync();

        // Confirm final state meets expectations
        (pool0, pool1,) = vars.pair.getPools();
        (reservoir0, reservoir1) = vars.pair.getReservoirs();
        // At least one reservoir is 0
        assert(reservoir0 == 0 || reservoir1 == 0);
        // Price hasn't changed
        assertEq(
            PriceAssertion.isPriceUnchanged(reservoir0, pool0Previous, pool1Previous, pool0, pool1),
            true,
            "New price outside of tolerance"
        );
    }

    function test__mintFee(uint256 mintAmount00, uint256 mintAmount01, uint256 inputAmount, bool inputToken0) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // Div by 3 to have room for two mints and a swap
        vm.assume(mintAmount00 < uint256(2 ** 112) / 3);
        vm.assume(mintAmount01 < uint256(2 ** 112) / 3);
        vm.assume(inputAmount < mintAmount00 && inputAmount < mintAmount01);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount00 > 1000);
        vm.assume(mintAmount01 > 1000);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount00, mintAmount01);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount01, mintAmount00);
            vm.assume(vars.amount0Out > 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount00);
        vars.token1.mint(vars.minter1, mintAmount01);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount00);
        vars.token1.transfer(address(vars.pair), mintAmount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Do the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();

        // Grant the minter tokens for a second mint
        (vars.pool0, vars.pool1,) = vars.pair.getPools();
        // Scale down by 10
        uint256 mintAmount10 = vars.pool0 / 10;
        uint256 mintAmount11 = (mintAmount10 * vars.pool1) / vars.pool0;
        vars.token0.mint(vars.minter1, mintAmount10);
        vars.token1.mint(vars.minter1, mintAmount11);
        // Estimate fee
        uint256 expectedFeeToBalance =
            PairMath.getProtocolFeeLiquidityMinted(vars.pair.totalSupply(), vars.pair.kLast(), vars.pool0 * vars.pool1);

        // Mint liquidity again to trigger the protocol fee being updated
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount10);
        vars.token1.transfer(address(vars.pair), mintAmount11);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Confirm new state is as expected
        assertEq(vars.pair.balanceOf(vars.feeTo), expectedFeeToBalance);
    }

    /// @dev Tests that the function correctly reverts when trying to update `reservoir{0,1}` to value that exceeds uint112
    function test__updateReservoirs_RevertsWhenExceedsMax(
        uint256 mintAmount1,
        address syncer,
        uint256 rebaseNumerator,
        uint256 rebaseDenominator
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount1 > 1000);
        // Keep rebase factor in sensible range
        rebaseNumerator = bound(rebaseNumerator, 1, 1000);
        rebaseDenominator = bound(rebaseDenominator, 1, 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(rebasingTokenA), address(tokenB)));
        vars.rebasingToken0 = ICommonMockRebasingERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        // Need a lot of token0 for the balance to exceed after a large rebase because the rebasing implementation has
        //   a max total supply of 2^128
        uint256 mintAmount0 = vars.rebasingToken0.mintableBalance();
        vars.rebasingToken0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.rebasingToken0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Apply rebase that will push a reservoir over 2^112
        vars.rebasingToken0.applyMultiplier(rebaseNumerator * (2 ** 112), rebaseDenominator);

        // Filter for when the new balance is large enough to overflow
        (vars.pool0,,) = vars.pair.getPools();
        vm.assume(vars.rebasingToken0.balanceOf(address(vars.pair)) - vars.pool0 > (2 ** 112));

        // Attempt sync
        vm.prank(syncer);
        vm.expectRevert(Overflow.selector);
        vars.pair.sync();
    }

    /// @dev Tests that the function correctly reverts when trying to update `pool{0,1}` to value that exceeds uint112
    function test__update_RevertsWhenExceedsMax(
        uint256 mintAmount0,
        uint256 mintAmount1,
        uint256 inputAmount,
        bool inputToken0
    ) public {
        // Make sure the amounts aren't liable to overflow 2**112
        // mintAmounts must be smaller still to ensure we don't overflow when calculating getOutputAmount using a
        //   very large inputAmount
        // Amounts must be non-zero, and must exceed minimum liquidity
        mintAmount0 = bound(mintAmount0, 1001, 2 ** 56);
        mintAmount1 = bound(mintAmount1, 1001, 2 ** 56);
        // Make sure the swap input amount will cause overflow at the end
        // But also keep it low enough to calculate getOutputAmount without issue
        inputAmount = bound(inputAmount, 2 ** 112, 2 ** 180);

        TestVariables memory vars;
        vars.amount0In;
        vars.amount1In;
        vars.amount0Out;
        vars.amount1Out;
        // Output amount must be non-zero
        if (inputToken0) {
            vars.amount0In = inputAmount;
            vars.amount1Out = PairMath.getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = PairMath.getOutputAmount(inputAmount, mintAmount1, mintAmount0);
            vm.assume(vars.amount0Out > 0);
        }

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.receiver = userE;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Attempt the swap
        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(Overflow.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    function test__update_CumulativePriceValuesUpdate(uint256 mintAmount0, uint256 mintAmount1, uint32 warpTime)
        public
    {
        // Make sure the amounts aren't liable to overflow 2**112
        vm.assume(mintAmount0 < (2 ** 112) / 2);
        vm.assume(mintAmount1 < (2 ** 112) / 2);
        // Amounts must be non-zero, and must exceed minimum liquidity
        vm.assume(mintAmount0 > 1000);
        vm.assume(mintAmount1 > 1000);

        TestVariables memory vars;
        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair2(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);

        // Mint initial liquidity
        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // Price cumulative values should start at zero
        assertEq(vars.pair.price0CumulativeLast(), 0);
        assertEq(vars.pair.price1CumulativeLast(), 0);

        // Calculate expected values
        (,, uint32 blockTimestampLast) = vars.pair.getPools();
        uint32 timeElapsed;
        unchecked {
            timeElapsed = warpTime - blockTimestampLast;
        }
        uint256 expectedPrice0CumulativeLast =
            uint256(UQ112x112.uqdiv(UQ112x112.encode(uint112(mintAmount1)), uint112(mintAmount0))) * timeElapsed;
        uint256 expectedPrice1CumulativeLast =
            uint256(UQ112x112.uqdiv(UQ112x112.encode(uint112(mintAmount0)), uint112(mintAmount1))) * timeElapsed;

        // Move time forward so that price can accrue
        vm.warp(warpTime);
        // Do sync to force update
        vars.pair.sync();

        // Confirm final state meets expectations
        assertEq(vars.pair.price0CumulativeLast(), expectedPrice0CumulativeLast);
        assertEq(vars.pair.price1CumulativeLast(), expectedPrice1CumulativeLast);
    }
}
