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

    struct LiquidityBalances {
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
    }

    /**
     * @inheritdoc IButtonswapPair
     */
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /**
     * @dev Denominator for basis points.
     */
    uint256 private constant BPS = 10_000;

    /**
     * @dev Numerator for when price volatility triggers maximum single-sided timelock duration
     */
    uint256 private constant maxVolatilityBps = 700;

    /**
     * @dev How long the minimum singled-sided timelock lasts for
     */
    uint256 private constant minTimelockDuration = 24 seconds;

    /**
     * @dev How long the maximum singled-sided timelock lasts for
     */
    uint256 private constant maxTimelockDuration = 24 hours;

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
    uint256 internal movingAveragePrice0Last;

    /**
     * @dev TODO
     */
    uint128 internal singleSidedTimelockDeadline;

    /**
     * @dev TODO
     */
    uint128 private unlocked = 1;

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

    /**
     * @dev TODO
     */
    modifier singleSidedTimelock() {
        if (block.timestamp < singleSidedTimelockDeadline) {
            revert SingleSidedTimelock();
        }
        _;
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
     * @dev Refer to `\notes\closest-bound-math.md`
     */
    function _closestBound(uint256 poolALower, uint256 poolB, uint256 _poolALast, uint256 _poolBLast)
        internal
        pure
        returns (uint256)
    {
        if ((poolALower * _poolBLast) + (_poolBLast / 2) < _poolALast * poolB) {
            return poolALower + 1;
        }
        return poolALower;
    }

    /**
     * @dev Refer to `\notes\liquidity-balances-math.md`
     */
    function _getLiquidityBalances(uint256 total0, uint256 total1)
        internal
        view
        returns (LiquidityBalances memory lb)
    {
        uint256 _pool0Last = uint256(pool0Last);
        uint256 _pool1Last = uint256(pool1Last);
        if (_pool0Last == 0 || _pool1Last == 0) {
            // Before Pair is initialized by first dual mint just return zeroes
        } else if (total0 == 0 || total1 == 0) {
            // Return zeroes, _getLiquidityBalancesUnsafe will get stuck in an infinite loop if called
        } else {
            if (total0 * _pool1Last < total1 * _pool0Last) {
                lb.pool0 = total0;
                // pool0Last/pool1Last == pool0/pool1 => pool1 == (pool0*pool1Last)/pool0Last
                // pool1Last/pool0Last == pool1/pool0 => pool1 == (pool0*pool1Last)/pool0Last
                lb.pool1 = (lb.pool0 * _pool1Last) / _pool0Last;
                lb.pool1 = _closestBound(lb.pool1, lb.pool0, _pool1Last, _pool0Last);
                // reservoir0 is zero, so no need to set it
                lb.reservoir1 = total1 - lb.pool1;
            } else {
                // Try the other way
                lb.pool1 = total1;
                // pool0Last/pool1Last == pool0/pool1 => pool0 == (pool1*pool0Last)/pool1Last
                // pool1Last/pool0Last == pool1/pool0 => pool0 == (pool1*pool0Last)/pool1Last
                lb.pool0 = (lb.pool1 * _pool0Last) / _pool1Last;
                lb.pool0 = _closestBound(lb.pool0, lb.pool1, _pool0Last, _pool1Last);
                // reservoir1 is zero, so no need to set it
                lb.reservoir0 = total0 - lb.pool0;
            }
            if (lb.pool0 > type(uint112).max || lb.pool1 > type(uint112).max) {
                revert Overflow();
            }
        }
    }

    /**
     * @dev TODO
     */
    function _updateSingleSidedTimelock(uint256 _movingAveragePrice0, uint112 pool0New, uint112 pool1New) internal {
        uint256 newPrice0 = uint256(UQ112x112.encode(pool1New).uqdiv(pool0New));
        uint256 priceDifference;
        if (newPrice0 > _movingAveragePrice0) {
            priceDifference = newPrice0 - _movingAveragePrice0;
        } else {
            priceDifference = _movingAveragePrice0 - newPrice0;
        }
        // priceDifference / ((_movingAveragePrice0 * maxVolatilityBps)/BPS)
        uint256 timelock = Math.min(
            minTimelockDuration
                + ((priceDifference * BPS * maxTimelockDuration) / (_movingAveragePrice0 * maxVolatilityBps)),
            maxTimelockDuration
        );
        uint128 timelockDeadline = uint128(block.timestamp + timelock);
        if (timelockDeadline > singleSidedTimelockDeadline) {
            singleSidedTimelockDeadline = timelockDeadline;
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
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        _pool0 = uint112(lb.pool0);
        _pool1 = uint112(lb.pool1);
        _reservoir0 = uint112(lb.reservoir0);
        _reservoir1 = uint112(lb.reservoir1);
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @notice TODO
     */
    function movingAveragePrice0() public view returns (uint256 _movingAveragePrice0) {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // overflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        uint256 currentPrice0 = uint256(UQ112x112.encode(pool1Last).uqdiv(pool0Last));
        if (timeElapsed == 0) {
            _movingAveragePrice0 = movingAveragePrice0Last;
        } else if (timeElapsed >= 24 hours) {
            _movingAveragePrice0 = currentPrice0;
        } else {
            _movingAveragePrice0 =
                ((movingAveragePrice0Last * (24 hours - timeElapsed)) + (currentPrice0 * timeElapsed)) / 24 hours;
        }
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
            // Initialize moving average
            movingAveragePrice0Last = uint256(UQ112x112.encode(pool1Last).uqdiv(pool0Last));
        } else {
            // Don't need to check that amountIn{0,1} are in the right ratio because the least generous ratio is used
            //   to determine the liquidityOut value, meaning any tokens that exceed that ratio are donated.
            // If total0 or total1 are zero (eg. due to negative rebases) then the function call reverts with div by zero
            liquidityOut =
                PairMath.getDualSidedMintLiquidityOutAmount(_totalSupply, amountIn0, amountIn1, total0, total1);
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
    function mintWithReservoir(uint256 amountIn, address to)
        external
        lock
        singleSidedTimelock
        returns (uint256 liquidityOut)
    {
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
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        if (lb.pool0 == 0 || lb.pool1 == 0) {
            revert InsufficientLiquidity();
        }
        uint256 _pool0Last = pool0Last;
        uint256 _pool1Last = pool1Last;
        if (lb.reservoir0 == 0) {
            // If reservoir0 is empty then we're adding token0 to pair with token1 reservoir liquidity
            SafeERC20.safeTransferFrom(IERC20(_token0), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token0).balanceOf(address(this)) - total0;

            uint256 token0ToSwap;
            uint256 equivalentToken1;
            (liquidityOut, token0ToSwap, equivalentToken1) = PairMath.getSingleSidedMintLiquidityOutAmountA(
                _totalSupply, amountIn, total0, total1, movingAveragePrice0()
            );

            // Ensure there's enough reservoir1 liquidity to do this without growing reservoir0
            // Refer to `/notes/mint-math.md`
            if (
                equivalentToken1 > lb.reservoir1
                    || (token0ToSwap * _pool1Last) / _pool0Last > lb.reservoir1 - equivalentToken1
            ) {
                revert InsufficientReservoir();
            }
        } else {
            // If reservoir1 is empty then we're adding token1 to pair with token0 reservoir liquidity
            SafeERC20.safeTransferFrom(IERC20(_token1), msg.sender, address(this), amountIn);
            // Use the balance delta as input amounts to ensure feeOnTransfer or similar tokens don't disrupt Pair math
            amountIn = IERC20(_token1).balanceOf(address(this)) - total1;

            uint256 token1ToSwap;
            uint256 equivalentToken0;
            (liquidityOut, token1ToSwap, equivalentToken0) = PairMath.getSingleSidedMintLiquidityOutAmountB(
                _totalSupply, amountIn, total0, total1, movingAveragePrice0()
            );

            // Ensure there's enough reservoir0 liquidity to do this without growing reservoir1
            // Refer to `/notes/mint-math.md`
            if (
                equivalentToken0 > lb.reservoir0
                    || (token1ToSwap * _pool0Last) / _pool1Last > lb.reservoir0 - equivalentToken0
            ) {
                revert InsufficientReservoir();
            }
        }

        if (liquidityOut == 0) {
            revert InsufficientLiquidityMinted();
        }
        _mint(to, liquidityOut);
        if (lb.reservoir0 == 0) {
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
        singleSidedTimelock
        returns (uint256 amountOut0, uint256 amountOut1)
    {
        uint256 _totalSupply = totalSupply;
        address _token0 = token0;
        address _token1 = token1;
        uint256 total0 = IERC20(_token0).balanceOf(address(this));
        uint256 total1 = IERC20(_token1).balanceOf(address(this));
        // Determine current pool liquidity
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        if (lb.pool0 == 0 || lb.pool1 == 0) {
            revert InsufficientLiquidity();
        }
        if (lb.reservoir0 == 0) {
            // If reservoir0 is empty then we're swapping amountOut0 for token1 from reservoir1
            (amountOut0, amountOut1) = PairMath.getSingleSidedBurnOutputAmountsB(
                _totalSupply, liquidityIn, total0, total1, movingAveragePrice0()
            );
            // Check there's enough reservoir liquidity to withdraw from
            // If `amountOut1` exceeds reservoir1 then it will result in reservoir0 growing from excess token0
            if (amountOut1 > lb.reservoir1) {
                revert InsufficientReservoir();
            }
        } else {
            // If reservoir0 isn't empty then we're swapping amountOut1 for token0 from reservoir0
            (amountOut0, amountOut1) = PairMath.getSingleSidedBurnOutputAmountsA(
                _totalSupply, liquidityIn, total0, total1, movingAveragePrice0()
            );
            // Check there's enough reservoir liquidity to withdraw from
            // If `amountOut0` exceeds reservoir0 then it will result in reservoir1 growing from excess token1
            if (amountOut0 > lb.reservoir0) {
                revert InsufficientReservoir();
            }
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
        {
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
            LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
            if (amountOut0 >= lb.pool0 || amountOut1 >= lb.pool1) {
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
            uint256 pool0New = total0 - lb.reservoir0;
            uint256 pool1New = total1 - lb.reservoir1;
            if (pool0New == 0 || pool1New == 0) {
                revert InvalidFinalPrice();
            }
            // Update to the actual amount of tokens the user sent in based on the delta between old and new pool balances
            if (pool0New > lb.pool0) {
                amountIn0 = pool0New - lb.pool0;
            } else {
                amountIn0 = 0;
            }
            if (pool1New > lb.pool1) {
                amountIn1 = pool1New - lb.pool1;
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
            if (pool0NewAdjusted * pool1NewAdjusted < (lb.pool0 * lb.pool1 * 1000 ** 2)) {
                revert KInvariant();
            }
            // Update moving average before `_updatePriceCumulative` updates `blockTimestampLast` and the new `poolXLast` values are set
            uint256 _movingAveragePrice0 = movingAveragePrice0();
            movingAveragePrice0Last = _movingAveragePrice0;
            _mintFee(lb.pool0, lb.pool1, pool0New, pool1New);
            _updatePriceCumulative(lb.pool0, lb.pool1);
            _updateSingleSidedTimelock(_movingAveragePrice0, uint112(pool0New), uint112(pool1New));
            // Update Pair last swap price
            pool0Last = uint112(pool0New);
            pool1Last = uint112(pool1New);
        }
        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, to);
    }
}
