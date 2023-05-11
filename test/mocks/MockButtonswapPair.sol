// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ButtonswapPair} from "../../src/ButtonswapPair.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MockButtonswapPair is ButtonswapPair {
    function mockSetPoolsLast(uint112 _pool0Last, uint112 _pool1Last) public {
        pool0Last = _pool0Last;
        pool1Last = _pool1Last;
    }

    function mockGetLiquidityBalances(uint256 total0, uint256 total1)
        public
        view
        returns (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1)
    {
        if (total0 > 0 && total1 > 0) {
            LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
            pool0 = lb.pool0;
            pool1 = lb.pool1;
            reservoir0 = lb.reservoir0;
            reservoir1 = lb.reservoir1;
        }
    }

    function mockGetSwappableReservoirLimit() public view returns (uint256 swappableReservoirLimit) {
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        swappableReservoirLimit = _getSwappableReservoirLimit(lb.reservoir0, lb.pool0, lb.pool1);
    }
}
