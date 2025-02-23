// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool, ISwapRouter} from "./interfaces/ILendingPool.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";

contract Position {
    error InvalidToken();
    error InsufficientCollateral();
    error InsufficientMinimumLeverage();
    error LeverageTooHigh();
    error NoChangeDetected();
    error ZeroAddress();
    error ZeroAmount();

    // Uniswap Router
    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address public immutable owner;
    address public immutable creator;
    ILendingPool public immutable lendingPool;
    uint256 public baseCollateral; // Represents the initial collateral amount.
    uint256 public effectiveCollateral; // Represents the total collateral after including borrowed collateral.
    uint256 public borrowShares;
    uint8 public leverage;
    uint8 public liquidationPrice;
    uint8 public health;
    uint8 public ltv;
    uint256 public lastUpdated;

    uint256 private flMode; // 0= no, 1=add leverage, 2=remove leverage, 3=close position

    constructor(address _lendingPool) {
        lendingPool = ILendingPool(_lendingPool);
    }

    function _emitUpdatePosition() internal {
        lastUpdated = block.timestamp;

        emit EventLib.UserPosition(
            address(lendingPool),
            msg.sender,
            address(this),
            lendingPool.loanToken(),
            lendingPool.collateralToken(),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            lastUpdated,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitSupplyCollateral() internal {
        emit EventLib.SupplyCollateral(
            address(lendingPool),
            msg.sender,
            address(this),
            lendingPool.loanToken(),
            lendingPool.collateralToken(),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitWithdrawCollateral() internal {
        emit EventLib.WithdrawCollateral(
            address(lendingPool),
            msg.sender,
            address(this),
            lendingPool.loanToken(),
            lendingPool.collateralToken(),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitBorrow() internal {
        emit EventLib.Borrow(
            address(lendingPool),
            msg.sender,
            address(this),
            lendingPool.loanToken(),
            lendingPool.collateralToken(),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitRepay() internal {
        emit EventLib.Repay(
            address(lendingPool),
            msg.sender,
            address(this),
            lendingPool.loanToken(),
            lendingPool.collateralToken(),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function convertCollateralPrice(uint256 collateralAmount) public view returns (uint256 amount) {
        return PriceConverterLib.getConversionRate(
            collateralAmount,
            AggregatorV2V3Interface(lendingPool.collateralTokenUsdDataFeed()),
            AggregatorV2V3Interface(lendingPool.loanTokenUsdDataFeed())
        );
    }

    function convertBorrowSharesToAmount(uint256 shares) public view returns (uint256) {
        return lendingPool.totalBorrowShares() == 0
            ? 0
            : (shares * lendingPool.totalBorrowAssets()) / lendingPool.totalBorrowShares();
    }

    function convertBorrowAmountToShares(uint256 amount) public view returns (uint256) {
        return lendingPool.totalBorrowAssets() == 0
            ? 0
            : (amount * lendingPool.totalBorrowShares()) / lendingPool.totalBorrowAssets();
    }

    function initialization(uint256 _baseCollateral, uint8 _leverage) external {
        baseCollateral = _baseCollateral;
        leverage = _leverage;
        effectiveCollateral = _baseCollateral * leverage;

        uint256 effectiveCollateralPrice = convertCollateralPrice(effectiveCollateral);
        uint256 borrowAmount = convertCollateralPrice(baseCollateral * (_leverage - 1));

        openPosition(_baseCollateral, borrowAmount);

        borrowShares = convertBorrowAmountToShares(borrowAmount);
        liquidationPrice = lendingPool.getLiquidationPrice(effectiveCollateral, borrowAmount);
        health = lendingPool.getHealth(effectiveCollateralPrice, borrowAmount);
        ltv = lendingPool.getLTV(effectiveCollateralPrice, borrowAmount);
    }

    function addCollateral(uint256 amount) public {
        _supplyCollateral(amount);
        _emitUpdatePosition();
    }

    function _supplyCollateral(uint256 amount) internal {
        IERC20(lendingPool.collateralToken()).transferFrom(msg.sender, address(this), amount);
        baseCollateral += amount;

        lendingPool.supplyCollateralByPosition(address(this), amount);

        _emitSupplyCollateral();
    }

    function withdrawCollateral(uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        if (amount > baseCollateral) revert InsufficientCollateral();
        baseCollateral -= amount;
        effectiveCollateral -= amount;
        _isHealthy();

        uint256 effectiveCollateralPrice = convertCollateralPrice(effectiveCollateral);
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);

        liquidationPrice = lendingPool.getLiquidationPrice(effectiveCollateral, borrowAmount);
        health = lendingPool.getHealth(effectiveCollateralPrice, borrowAmount);
        ltv = lendingPool.getLTV(effectiveCollateralPrice, borrowAmount);

        lendingPool.withdrawCollateralByPosition(address(this), amount);

        _emitUpdatePosition();
        _emitWithdrawCollateral();

        IERC20(lendingPool.collateralToken()).transfer(msg.sender, amount);
    }

    function _borrow(uint256 amount) internal {
        uint256 shares = lendingPool.borrowByPosition(address(this), amount);
        borrowShares += shares;
        _isHealthy();
        _emitBorrow();
    }

    function openPosition(uint256 amount, uint256 debt) public {
        _supplyCollateral(amount);

        flMode = 1;

        _borrow(debt);
        ILendingPool(lendingPool).flashLoan(address(ILendingPool(lendingPool).loanToken()), debt, "");

        flMode = 0;

        _emitUpdatePosition();
    }

    function onFlashLoan(address token, uint256 amount, bytes calldata) external {
        if (token != ILendingPool(lendingPool).loanToken()) revert InvalidToken();

        if (flMode == 1) _flAddLeverage(token, amount);

        // repay flashloan
        IERC20(token).approve(address(lendingPool), amount);
    }

    function _flAddLeverage(address token, uint256 amount) internal {
        uint256 amountOut = _swap(token, ILendingPool(lendingPool).collateralToken(), amount);
        effectiveCollateral += amountOut;
    }

    function _swap(address loanToken, address collateralToken, uint256 amount) internal returns (uint256) {
        ISwapRouter(router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: loanToken,
                tokenOut: collateralToken,
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 amountOut = IERC20(ILendingPool(lendingPool).collateralToken()).balanceOf(address(this));

        IERC20(lendingPool.collateralToken()).approve(address(lendingPool), amountOut);
        lendingPool.supplyCollateralByPosition(address(this), amountOut);

        _emitSupplyCollateral();

        return (amountOut);
    }

    function _isHealthy() internal view {
        uint256 collateral = convertCollateralPrice(baseCollateral);

        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        if (borrowAmount > collateral) revert InsufficientCollateral();

        uint256 allowedBorrowAmount = (collateral - borrowAmount) * ltv / 100;
        if (borrowAmount > allowedBorrowAmount) revert InsufficientCollateral();
    }

    function updateLeverage(uint8 newLeverage) external {
        if (newLeverage < 1) revert InsufficientMinimumLeverage();
        if (newLeverage > 10) revert LeverageTooHigh();

        uint256 oldLeverage = leverage;
        if (newLeverage == oldLeverage) revert NoChangeDetected();

        uint256 oldBorrowAmount = (borrowShares * lendingPool.totalSupplyShares()) / lendingPool.totalSupplyAssets();
        uint256 newEffectiveCollateral = baseCollateral * newLeverage;
        uint256 newBorrowAmount = convertCollateralPrice(baseCollateral * (newLeverage - 1));

        // adjust leverage
        if (newLeverage > oldLeverage) {
            // increase
            uint256 additionalBorrow = newBorrowAmount - oldBorrowAmount;
            flMode = 1;

            _borrow(additionalBorrow);
            ILendingPool(lendingPool).flashLoan(address(ILendingPool(lendingPool).loanToken()), additionalBorrow, "");

            flMode = 0;
        } else if (newLeverage < oldLeverage) {
            // decrease
            uint256 repayAmount = oldBorrowAmount - newBorrowAmount;
            uint256 repayCollateral = newEffectiveCollateral - effectiveCollateral;
            uint256 amountOut = _swap(lendingPool.loanToken(), lendingPool.collateralToken(), repayCollateral);
            lendingPool.repayByPosition(msg.sender, repayAmount);
        }

        effectiveCollateral = newEffectiveCollateral;
        leverage = newLeverage;
        borrowShares = (newBorrowAmount * lendingPool.totalSupplyAssets()) / lendingPool.totalSupplyShares();
        liquidationPrice = lendingPool.getLiquidationPrice(effectiveCollateral, newBorrowAmount);
        health = lendingPool.getHealth(effectiveCollateral, newBorrowAmount);
        ltv = lendingPool.getLTV(effectiveCollateral, newBorrowAmount);
        _emitUpdatePosition();
    }

    function closePosition() external {
        uint256 borrowAmount = (borrowShares * lendingPool.totalSupplyShares()) / lendingPool.totalSupplyAssets();

        // Swap senilai
        uint256 amountOut = _swap(lendingPool.loanToken(), lendingPool.collateralToken(), borrowAmount);

        // repayByPosition
        lendingPool.repayByPosition(msg.sender, borrowAmount);

        if (baseCollateral > 0) {
            lendingPool.withdrawCollateralByPosition(address(this), baseCollateral);
        }
        borrowShares = 0;
        baseCollateral = 0;
        effectiveCollateral = 0;
        leverage = 1;
        liquidationPrice = 0;
        health = 0;
        ltv = 0;
    }
}
