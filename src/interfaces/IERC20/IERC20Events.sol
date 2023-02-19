// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20Events {
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Transfer(address indexed from, address indexed to, uint256 value);
}
