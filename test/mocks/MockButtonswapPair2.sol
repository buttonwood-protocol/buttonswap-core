// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ButtonswapPair2} from "../../src/ButtonswapPair2.sol";

contract MockButtonswapPair2 is ButtonswapPair2 {
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
            (pool0, pool1, reservoir0, reservoir1) = _getLiquidityBalances(total0, total1);
        }
    }
}
