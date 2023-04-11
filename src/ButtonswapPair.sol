// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IButtonswapPair} from "./interfaces/IButtonswapPair/IButtonswapPair.sol";
import {ButtonswapERC20} from "./ButtonswapERC20.sol";
import {Math} from "./libraries/Math.sol";
import {PairMath} from "./libraries/PairMath.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IButtonswapFactory} from "./interfaces/IButtonswapFactory/IButtonswapFactory.sol";
import {IButtonswapCallee} from "./interfaces/IButtonswapCallee.sol";

contract ButtonswapPair is IButtonswapPair, ButtonswapERC20 {
    using UQ112x112 for uint224;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public factory;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public token0;

    /**
     * @inheritdoc IButtonswapPair
     */
    address public token1;

    /**
     * @dev TODO
     */
    uint112 internal pool0Last;

    /**
     * @dev TODO
     */
    uint112 internal pool1Last;

    /**
     * @dev TODO
     */
    uint32 internal blockTimestampLast;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public price0CumulativeLast;

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public price1CumulativeLast;

    /**
     * @dev TODO
     */
    uint256 private unlocked = 1;

    /**
     * @dev TODO
     */
    modifier lock() {
        if (unlocked == 0) {
            revert Locked();
        }
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function initialize(address _token0, address _token1) external {
        // sufficient check
        if (msg.sender != factory) {
            revert Forbidden();
        }
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev TODO
     * if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
     */
    function _mintFee(uint256 pool0, uint256 pool1, uint256 pool0New, uint256 pool1New) internal {
        address feeTo = IButtonswapFactory(factory).feeTo();
        if (feeTo != address(0)) {
            uint256 liquidityOut =
                PairMath.getProtocolFeeLiquidityMinted(totalSupply, pool0 * pool1, pool0New * pool1New);
            if (liquidityOut > 0) {
                _mint(feeTo, liquidityOut);
            }
        }
    }

    /**
     * @dev TODO
     */
    function _updatePriceCumulative(uint256 pool0, uint256 pool1) internal {
        uint112 _pool0 = uint112(pool0);
        uint112 _pool1 = uint112(pool1);
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // overflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        if (timeElapsed > 0 && pool0 != 0 && pool1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += uint256(UQ112x112.encode(_pool1).uqdiv(_pool0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_pool0).uqdiv(_pool1)) * timeElapsed;
            }
            blockTimestampLast = blockTimestamp;
        }
    }

    /**
     * @dev TODO
     */
    function _closestBound(uint256 poolALower, uint256 poolB, uint256 _poolALast, uint256 _poolBLast)
        internal
        pure
        returns (uint256)
    {
        // If upperProdDiff is negative, then upperProdDiff is too and further from 0
        // If upperProdDiff is positive but less than poolBLast/2, then lowerProdDiff is negative and further from 0 (because they're poolBLast apart)
        if (poolALower * _poolBLast + _poolBLast < _poolALast * poolB + _poolBLast / 2) {
            return poolALower + 1;
        }
        return poolALower;
    }

    /**
     * @dev TODO
     * @dev This method lacks proper checks and should not be called directly
     */
    function _getLiquidityBalancesUnsafe(uint256 total0, uint256 total1, uint256 _pool0Last, uint256 _pool1Last)
        internal
        pure
        returns (uint256 pool0, uint256 pool1)
    {
        if (total0 < 1000 || total1 < 1000) {
            // Scale total{0,1} up to over 1000 to avoid precision issues with extremely low values
            // With, for example, _pool1Last=1 and total1=1 and a token0 rebase of x1.5 we would otherwise try and
            //   succeed trying the first way, however new pool0 would be x1.5 what it was before without pool1
            //   changing, with the effect of the price ratio changing drastically in an undesired way.
            (pool0, pool1) = _getLiquidityBalancesUnsafe(total0 * 10, total1 * 10, _pool0Last, _pool1Last);
            // Now scale output values back down again
            pool0 /= 10;
            pool1 /= 10;
        } else {
            // Try it one way
            pool0 = total0;
            // pool0Last/pool1Last == pool0/pool1 => pool1 == (pool0*pool1Last)/pool0Last
            // pool1Last/pool0Last == pool1/pool0 => pool1 == (pool0*pool1Last)/pool0Last
            pool1 = (pool0 * _pool1Last) / _pool0Last;
            pool1 = _closestBound(pool1, pool0, _pool1Last, _pool0Last);
            if (pool1 > total1) {
                // Try the other way
                pool1 = total1;
                // pool0Last/pool1Last == pool0/pool1 => pool0 == (pool1*pool0Last)/pool1Last
                // pool1Last/pool0Last == pool1/pool0 => pool0 == (pool1*pool0Last)/pool1Last
                pool0 = (pool1 * _pool0Last) / _pool1Last;
                pool0 = _closestBound(pool0, pool1, _pool0Last, _pool1Last);
            }
        }
    }

    /**
     * @dev TODO
     */
    function _getLiquidityBalances(uint256 total0, uint256 total1)
        internal
        view
        returns (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1)
    {
        uint256 _pool0Last = uint256(pool0Last);
        uint256 _pool1Last = uint256(pool1Last);
        if (_pool0Last == 0 || _pool1Last == 0) {
            // Before Pair is initialized by first dual mint just return zeroes
        } else if (total0 == 0 || total1 == 0) {
            // Return zeroes, _getLiquidityBalancesUnsafe will get stuck in an infinite loop if called
        } else {
            (pool0, pool1) = _getLiquidityBalancesUnsafe(total0, total1, _pool0Last, _pool1Last);
            // Either pool0 is set to total0 or pool1 is set to total1 in _getLiquidityBalancesUnsafe
            // This means that one of the reservoir values will definitely be zero, and we don't need to check for it
            reservoir0 = total0 - pool0;
            reservoir1 = total1 - pool1;
            // TODO could scale pool to fit instead, transferring excess to reservoir?
            if (pool0 > type(uint112).max || pool1 > type(uint112).max) {
                revert Overflow();
            }
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function getLiquidityBalances()
        external
        view
        returns (uint112 _pool0, uint112 _pool1, uint112 _reservoir0, uint112 _reservoir1, uint32 _blockTimestampLast)
    {
        uint256 total0 = IERC20(token0).balanceOf(address(this));
        uint256 total1 = IERC20(token1).balanceOf(address(this));
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) = _getLiquidityBalances(total0, total1);
        _pool0 = uint112(pool0);
        _pool1 = uint112(pool1);
        _reservoir0 = uint112(reservoir0);
        _reservoir1 = uint112(reservoir1);
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function mint(uint256 amountIn0, uint256 amountIn1, address to) external lock returns (uint256 liquidityOut) {
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current pool liquidity
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) = _getLiquidityBalances(total0, total1);
        SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn0);
        SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn1);
        // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
        amountIn0 = IERC20(_token0).balanceOf(address(this)) - total0;
        amountIn1 = IERC20(_token1).balanceOf(address(this)) - total1;

        if (_totalSupply == 0) {
            liquidityOut = Math.sqrt(amountIn0 * amountIn1) - MINIMUM_LIQUIDITY;
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
            // Initialize Pair last swap price
            pool0Last = uint112(amountIn0);
            pool1Last = uint112(amountIn1);
            // Initialize timestamp so first price update is accurate
            blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        } else {
            if (pool0 == 0 || pool1 == 0) {
                revert InsufficientLiquidity();
            }
            // Check that value0AddedInTermsOf1 == amountIn1 or value1AddedInTermsOf0 == amountIn0
            uint256 value0AddedInTermsOf1 = (amountIn0 * pool1) / pool0;
            if (value0AddedInTermsOf1 != amountIn1) {
                uint256 value1AddedInTermsOf0 = (amountIn1 * pool0) / pool1;
                if (value1AddedInTermsOf0 != amountIn0) {
                    revert UnequalMint();
                }
            }
            liquidityOut = PairMath.getDualSidedMintLiquidityOutAmount(
                _totalSupply, amountIn0, amountIn1, pool0, pool1, reservoir0, reservoir1
            );
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        emit Mint(msg.sender, amountIn0, amountIn1);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function mintWithReservoir(uint256 amountIn, address to) external lock returns (uint256 liquidityOut) {
        if (amountIn == 0) {
            revert InsufficientLiquidityAdded();
        }
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            revert Uninitialized();
        }
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current pool liquidity
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) = _getLiquidityBalances(total0, total1);
        if (pool0 == 0 || pool1 == 0) {
            revert InsufficientLiquidity();
        }
        if (reservoir0 == 0) {
            // If reservoir0 is empty then we're adding token0 to pair with token1 liquidity
            SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token0).balanceOf(address(this)) - total0;

            // Check there's enough reservoir liquidity to pair with the amountIn
            if ((amountIn * pool1) / pool0 > reservoir1) {
                revert InsufficientReservoir();
            }

            liquidityOut =
                PairMath.getSingleSidedMintLiquidityOutAmount(_totalSupply, amountIn, pool1, pool0, reservoir1);
        } else {
            // If reservoir1 is empty then we're adding token1 to pair with token0 liquidity
            SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token1).balanceOf(address(this)) - total1;

            // Check there's enough reservoir liquidity to pair with the amountIn
            if ((amountIn * pool0) / pool1 > reservoir0) {
                revert InsufficientReservoir();
            }

            liquidityOut =
                PairMath.getSingleSidedMintLiquidityOutAmount(_totalSupply, amountIn, pool0, pool1, reservoir0);
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        if (reservoir0 == 0) {
            emit Mint(msg.sender, amountIn, 0);
        } else {
            emit Mint(msg.sender, 0, amountIn);
        }
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function burn(uint256 liquidityIn, address to) external lock returns (uint256 amountOut0, uint256 amountOut1) {
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));

        (amountOut0, amountOut1) = PairMath.getDualSidedBurnOutputAmounts(_totalSupply, liquidityIn, total0, total1);

        if (amountOut0 == 0 || amountOut1 == 0) {
            revert InsufficientLiquidityBurned();
        }
        _burn(msg.sender, liquidityIn);
        SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        emit Burn(msg.sender, amountOut0, amountOut1, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function burnFromReservoir(uint256 liquidityIn, address to)
        external
        lock
        returns (uint256 amountOut0, uint256 amountOut1)
    {
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current pool liquidity
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) = _getLiquidityBalances(total0, total1);
        if (pool0 == 0 || pool1 == 0) {
            revert InsufficientLiquidity();
        }

        (amountOut0, amountOut1) =
            PairMath.getSingleSidedBurnOutputAmounts(_totalSupply, liquidityIn, pool0, pool1, reservoir0, reservoir1);

        if (amountOut0 > reservoir0 || amountOut1 > reservoir1) {
            revert InsufficientReservoir();
        }
        _burn(msg.sender, liquidityIn);
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        } else if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        } else {
            revert InsufficientLiquidityBurned();
        }
        emit Burn(msg.sender, amountOut0, amountOut1, to);
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    function swap(
        uint256 amountIn0,
        uint256 amountIn1,
        uint256 amountOut0,
        uint256 amountOut1,
        address to,
        bytes calldata data
    ) external lock {
        if (amountOut0 == 0 && amountOut1 == 0) {
            revert InsufficientOutputAmount();
        }
        address _token0 = token0;
        address _token1 = token1;
        if (to == _token0 || to == _token1) {
            revert InvalidRecipient();
        }
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current pool liquidity
        (uint256 pool0, uint256 pool1, uint256 reservoir0, uint256 reservoir1) = _getLiquidityBalances(total0, total1);
        if (amountOut0 >= pool0 || amountOut1 >= pool1) {
            revert InsufficientLiquidity();
        }
        // Transfer in the specified input
        if (amountIn0 > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn0);
        }
        if (amountIn1 > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn1);
        }
        // Optimistically transfer output
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(_token0), to, amountOut0);
        }
        if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(_token1), to, amountOut1);
        }
        if (data.length > 0) {
            IButtonswapCallee(to).buttonswapCall(msg.sender, amountOut0, amountOut1, data);
        }
        // Refresh balances
        total0 = IERC20(_token0).balanceOf(address(this));
        total1 = IERC20(_token1).balanceOf(address(this));
        // The reservoir balances must remain unchanged during a swap, so all balance changes impact the pool balances
        uint256 pool0New = total0 - reservoir0;
        uint256 pool1New = total1 - reservoir1;
        if (pool0New == 0 || pool1New == 0) {
            revert InvalidFinalPrice();
        }
        // Update to the actual amount of tokens the user sent in based on the delta between old and new pool balances
        if (pool0New > pool0) {
            amountIn0 = pool0New - pool0;
        } else {
            amountIn0 = 0;
        }
        if (pool1New > pool1) {
            amountIn1 = pool1New - pool1;
        } else {
            amountIn1 = 0;
        }
        // If after accounting for input and output cancelling one another out, fee on transfer, etc there is no
        //   input tokens in real terms then revert.
        if (amountIn0 == 0 && amountIn1 == 0) {
            revert InsufficientInputAmount();
        }
        uint256 pool0NewAdjusted = (pool0New * 1000) - (amountIn0 * 3);
        uint256 pool1NewAdjusted = (pool1New * 1000) - (amountIn1 * 3);
        // After account for 0.3% fees, the new K must not be less than the old K
        if (pool0NewAdjusted * pool1NewAdjusted < (pool0 * pool1 * 1000 ** 2)) {
            revert KInvariant();
        }
        _mintFee(pool0, pool1, pool0New, pool1New);
        _updatePriceCumulative(pool0, pool1);
        // Update Pair last swap price
        pool0Last = uint112(pool0New);
        pool1Last = uint112(pool1New);

        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }
}
