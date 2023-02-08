// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

interface IButtonwoodCallee {
    function buttonwoodCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
