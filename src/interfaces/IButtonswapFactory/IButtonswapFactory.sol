// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapFactoryErrors} from "./IButtonswapFactoryErrors.sol";
import {IButtonswapFactoryEvents} from "./IButtonswapFactoryEvents.sol";

interface IButtonswapFactory is IButtonswapFactoryErrors, IButtonswapFactoryEvents {
    /**
     * @notice Returns the current address for `feeTo`.
     * The owner of this address receives the protocol fee as it is collected over time.
     * @return _feeTo The `feeTo` address
     */
    function feeTo() external view returns (address _feeTo);

    /**
     * @notice Returns the current address for `feeToSetter`.
     * The owner of this address has the power to update both `feeToSetter` and `feeTo`.
     * @return _feeToSetter The `feeToSetter` address
     */
    function feeToSetter() external view returns (address _feeToSetter);

    /**
     * @notice Returns the current state of locked creation.
     * If true, then no new pairs, only feeToSetter can create new pairs
     * @return _lockedCreation The `lockedCreation` state
     */
    function lockedCreation() external view returns (bool _lockedCreation);

    /**
     * @notice Get the (unique) Pair address created for the given combination of `tokenA` and `tokenB`.
     * If the Pair does not exist then zero address is returned.
     * @param tokenA The first unsorted token
     * @param tokenB The second unsorted token
     * @return pair The address of the Pair instance
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /**
     * @notice Get the Pair address at the given `index`, ordered chronologically.
     * @param index The index to query
     * @return pair The address of the Pair created at the given `index`
     */
    function allPairs(uint256 index) external view returns (address pair);

    /**
     * @notice Get the current total number of Pairs created
     * @return count The total number of Pairs created
     */
    function allPairsLength() external view returns (uint256 count);

    /**
     * @notice Creates a new {ButtonswapPair} instance for the given unsorted tokens `tokenA` and `tokenB`.
     * @dev The tokens are sorted later, but can be provided to this method in either order.
     * @param tokenA The first unsorted token address
     * @param tokenB The second unsorted token address
     * @return pair The address of the new {ButtonswapPair} instance
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @notice Updates the address that receives the protocol fee.
     * This can only be called by the `feeToSetter` address.
     * @param _feeTo The new address
     */
    function setFeeTo(address _feeTo) external;

    /**
     * @notice Updates the address that has the power to set the `feeToSetter` and `feeTo` addresses.
     * This can only be called by the `feeToSetter` address.
     * @param _feeToSetter The new address
     */
    function setFeeToSetter(address _feeToSetter) external;

    /**
     * @notice Updates the state of locked creation.
     * This can only be called by the `feeToSetter` address.
     * @param _lockedCreation The new state
     */
    function setLockedCreation(bool _lockedCreation) external;
}
