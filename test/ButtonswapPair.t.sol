// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IButtonswapPairEvents, IButtonswapPairErrors} from "src/interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapPair} from "src/ButtonswapPair.sol";
import {Math} from "src/libraries/Math.sol";
import {MockERC20} from "mock-contracts/MockERC20.sol";
import {MockRebasingERC20} from "mock-contracts/MockRebasingERC20.sol";
import {MockUFragments} from "mock-contracts/MockUFragments.sol";
import {ICommonMockRebasingERC20} from "mock-contracts/interfaces/ICommonMockRebasingERC20.sol";
import {MockButtonswapFactory} from "test/mocks/MockButtonswapFactory.sol";
import {Utils} from "test/utils/Utils.sol";

contract ButtonswapPairTest is Test, IButtonswapPairEvents, IButtonswapPairErrors {
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
        MockButtonswapFactory factory;
        ButtonswapPair pair;
        MockERC20 token0;
        MockERC20 token1;
        ICommonMockRebasingERC20 rebasingToken0;
        ICommonMockRebasingERC20 rebasingToken1;
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
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

    /// @dev Refer to `/notes/swap-math.md`
    function getOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput)
        public
        pure
        returns (uint256)
    {
        return (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));
    }

    function setUp() public {
        tokenA = new MockERC20("TokenA", "TKNA");
        tokenB = new MockERC20("TokenB", "TKNB");
        // rebasingTokenA = ICommonMockRebasingERC20(address(MockRebasingERC20("TokenA", "TKNA", 18)));
        // rebasingTokenB = ICommonMockRebasingERC20(address(new MockRebasingERC20("TokenB", "TKNB", 18)));
        rebasingTokenA = ICommonMockRebasingERC20(address(new MockUFragments()));
        rebasingTokenB = ICommonMockRebasingERC20(address(new MockUFragments()));
    }

    function test_initialize(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair pair = new ButtonswapPair();

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
        (uint256 pool0, uint256 pool1,) = pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = pair.getReservoirs();
        assertEq(pool0, 0);
        assertEq(pool1, 0);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
    }

    function test_initialize_CannotCallWhenNotCreator(address factory, address token0, address token1) public {
        vm.assume(factory != address(this));

        vm.prank(factory);
        ButtonswapPair pair = new ButtonswapPair();

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
        vars.pair = ButtonswapPair(vars.factory.createPair(token0, token1));

        assertEq(vars.pair.token0(), token0);
        assertEq(vars.pair.token1(), token1);
        assertEq(vars.pair.totalSupply(), 0);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 0);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter1, amount0, amount1);
        uint256 liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), liquidity1 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), liquidity1);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        uint256 liquidity1 = vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectEmit(true, true, true, true);
        emit Mint(vars.minter2, amount10, amount11);
        uint256 liquidity2 = vars.pair.mint(vars.minter2);
        vm.stopPrank();

        // 1000 liquidity was minted to zero address instead of minter1
        assertEq(vars.pair.totalSupply(), liquidity1 + liquidity2 + 1000);
        assertEq(vars.pair.balanceOf(vars.zeroAddress), 1000);
        assertEq(vars.pair.balanceOf(vars.feeToSetter), 0);
        assertEq(vars.pair.balanceOf(vars.feeTo), 0);
        assertEq(vars.pair.balanceOf(vars.minter1), liquidity1);
        assertEq(vars.pair.balanceOf(vars.minter2), liquidity2);
        (uint256 pool0, uint256 pool1,) = vars.pair.getPools();
        (uint256 reservoir0, uint256 reservoir1) = vars.pair.getReservoirs();
        assertEq(pool0, amount00 + amount10);
        assertEq(pool1, amount01 + amount11);
        assertEq(reservoir0, 0);
        assertEq(reservoir1, 0);
        // After first mint subsequent liquidity is calculated based on ratio of value added to value already in pair
        assertEq(liquidity2, vars.pair.totalSupply() * (amount10 * 2) / (pool0 * 2));
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectRevert(UnequalMint.selector);
        vars.pair.mint(vars.minter2);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(vars.minter1);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount0);
        vars.token1.mint(vars.minter1, amount1);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount0);
        vars.token1.transfer(address(vars.pair), amount1);
        vm.expectRevert(stdError.arithmeticError);
        vars.pair.mint(vars.minter1);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, amount00);
        vars.token1.mint(vars.minter1, amount01);
        vars.token0.mint(vars.minter2, amount10);
        vars.token1.mint(vars.minter2, amount11);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), amount00);
        vars.token1.transfer(address(vars.pair), amount01);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.minter2);
        vars.token0.transfer(address(vars.pair), amount10);
        vars.token1.transfer(address(vars.pair), amount11);
        vm.expectRevert(InsufficientLiquidityMinted.selector);
        vars.pair.mint(vars.minter2);
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
            vars.amount1Out = getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = getOutputAmount(inputAmount, mintAmount1, mintAmount0);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectEmit(true, true, true, true);
        emit Swap(vars.swapper1, vars.amount0In, vars.amount1In, vars.amount0Out, vars.amount1Out, vars.receiver);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();

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
            vars.amount1Out = getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out == 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = getOutputAmount(inputAmount, mintAmount1, mintAmount0);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InsufficientOutputAmount.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

    function test_swap_CannotSwapForMoreTokensThanInPool(
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InsufficientLiquidity.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

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
        vars.amount1Out = getOutputAmount(inputAmount, mintAmount0, mintAmount1);
        vm.assume(vars.amount1Out > 0);

        vars.feeToSetter = userA;
        vars.feeTo = userB;
        vars.minter1 = userC;
        vars.swapper1 = userD;
        vars.factory = new MockButtonswapFactory(vars.feeToSetter);
        vm.prank(vars.feeToSetter);
        vars.factory.setFeeTo(vars.feeTo);
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
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

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(InvalidRecipient.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }

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
            vars.amount1Out = getOutputAmount(inputAmount, mintAmount0, mintAmount1);
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = getOutputAmount(inputAmount, mintAmount1, mintAmount0);
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

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
            vars.amount1Out = getOutputAmount(inputAmount, mintAmount0, mintAmount1) + 1;
            vm.assume(vars.amount1Out > 0);
        } else {
            vars.amount1In = inputAmount;
            vars.amount0Out = getOutputAmount(inputAmount, mintAmount1, mintAmount0) + 1;
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
        vars.pair = ButtonswapPair(vars.factory.createPair(address(tokenA), address(tokenB)));
        vars.token0 = MockERC20(vars.pair.token0());
        vars.token1 = MockERC20(vars.pair.token1());
        vars.token0.mint(vars.minter1, mintAmount0);
        vars.token1.mint(vars.minter1, mintAmount1);
        vars.token0.mint(vars.swapper1, vars.amount0In);
        vars.token1.mint(vars.swapper1, vars.amount1In);

        vm.startPrank(vars.minter1);
        vars.token0.transfer(address(vars.pair), mintAmount0);
        vars.token1.transfer(address(vars.pair), mintAmount1);
        vars.pair.mint(vars.minter1);
        vm.stopPrank();

        vm.startPrank(vars.swapper1);
        vars.token0.transfer(address(vars.pair), vars.amount0In);
        vars.token1.transfer(address(vars.pair), vars.amount1In);
        vm.expectRevert(KInvariant.selector);
        vars.pair.swap(vars.amount0Out, vars.amount1Out, vars.receiver, new bytes(0));
        vm.stopPrank();
    }
}
