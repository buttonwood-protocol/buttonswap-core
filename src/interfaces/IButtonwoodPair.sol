// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import "./IButtonwoodERC20.sol";

interface IButtonwoodPair is IButtonwoodERC20 {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 pool0, uint112 pool1);
    event SyncReservoir(uint112 reservoir0, uint112 reservoir1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getPools() external view returns (uint112 poolA, uint112 poolB, uint32 blockTimestampLast);

    function getReservoirs() external view returns (uint112 reservoirA, uint112 reservoirB);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function mintWithReservoir(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amountA, uint256 amountB);

    function burnFromReservoir(address to) external returns (uint256 amountA, uint256 amountB);

    function swap(uint256 amountAOut, uint256 amountBOut, address to, bytes calldata data) external;

    function sync() external;

    function initialize(address, address) external;
}
