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
    error PositionAtRisk();
    error ZeroAddress();
    error ZeroAmount();

    // Uniswap Router
    address public router = 0x0DA34E6C6361f5B8f5Bdb6276fEE16dD241108c8;

    address public immutable owner;
    address public immutable creator;
    ILendingPool public immutable lendingPool;
    uint256 public baseCollateral; // Represents the initial collateral amount.
    uint256 public effectiveCollateral; // Represents the total collateral after including borrowed collateral.
    uint256 public borrowShares;
    uint8 public leverage = 100;
    uint8 public liquidationPrice;
    uint8 public health;
    uint8 public ltv;
    uint256 public lastUpdated;

    uint256 private flMode; // 0= no, 1=add leverage, 2=remove leverage, 3=close position

    constructor(address _lendingPool, address _creator) {
        owner = msg.sender;
        creator = _creator;
        lendingPool = ILendingPool(_lendingPool);
    }

    function _emitUpdatePosition() internal {
        lastUpdated = block.timestamp;

        emit EventLib.UserPosition(
            address(lendingPool),
            creator,
            address(this),
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitSupplyCollateral() internal {
        emit EventLib.SupplyCollateral(
            address(lendingPool),
            creator,
            address(this),
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
            creator,
            address(this),
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
            creator,
            address(this),
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
            creator,
            address(this),
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

    function setRiskInfo(uint256 _effectiveCollateral, uint256 _borrowAmount) public {
        uint256 effectiveCollateralPrice = convertCollateralPrice(_effectiveCollateral);

        liquidationPrice = lendingPool.getLiquidationPrice(_effectiveCollateral, _borrowAmount);
        health = lendingPool.getHealth(effectiveCollateralPrice, _borrowAmount);
        ltv = lendingPool.getLTV(effectiveCollateralPrice, _borrowAmount);
    }

    function addCollateral(uint256 amount) public {
        _supplyCollateral(amount);
        _emitUpdatePosition();
    }

    function _supplyCollateral(uint256 amount) internal {
        IERC20(lendingPool.collateralToken()).transferFrom(msg.sender, address(this), amount);
        baseCollateral += amount;
        effectiveCollateral += amount;

        IERC20(lendingPool.collateralToken()).approve(address(lendingPool), amount);
        lendingPool.supplyCollateralByPosition(address(this), amount);

        _emitSupplyCollateral();
    }

    function withdrawCollateral(uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        if (amount > baseCollateral) revert InsufficientCollateral();
        baseCollateral -= amount;
        effectiveCollateral -= amount;
        _checkHealth();

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
        _checkHealth();
        _emitBorrow();
    }

    function borrow(uint256 amount) external {
        _borrow(amount);
    }

    function openPosition(uint256 amount, uint256 debt) public {
        _supplyCollateral(amount);

        flMode = 1;

        ILendingPool(lendingPool).flashLoan(address(ILendingPool(lendingPool).loanToken()), debt, "");
        _borrow(debt);

        flMode = 0;

        _emitUpdatePosition();
    }

    function onFlashLoan(address token, uint256 amount, bytes calldata) external {
        if (token != lendingPool.loanToken()) revert InvalidToken();

        if (flMode == 1) _flAddLeverage(token, amount);

        // repay flashloan
        IERC20(token).approve(address(lendingPool), amount);
    }

    function _flAddLeverage(address token, uint256 amount) internal {
        uint256 amountOut = _swap(token, lendingPool.collateralToken(), amount);
        effectiveCollateral += amountOut;
    }

    function _swap(address loanToken, address collateralToken, uint256 amount) internal returns (uint256) {
        IERC20(loanToken).approve(address(router), amount);

        ISwapRouter(router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: loanToken,
                tokenOut: collateralToken,
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: amount * 98 / 100,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 amountOut = IERC20(lendingPool.collateralToken()).balanceOf(address(this));

        IERC20(lendingPool.collateralToken()).approve(address(lendingPool), amountOut);
        lendingPool.supplyCollateralByPosition(address(this), amountOut);

        _emitSupplyCollateral();

        return amountOut;
    }

    function _checkHealth() internal view {
        uint256 effectiveCollateralPrice = convertCollateralPrice(effectiveCollateral);
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        uint256 healthFactor = (effectiveCollateralPrice * lendingPool.ltp()) / borrowAmount;

        if (healthFactor < 1) revert PositionAtRisk();
    }

    function updateLeverage(uint8 newLeverage) external {
        if (newLeverage < 100) revert InsufficientMinimumLeverage();
        if (newLeverage > 500) revert LeverageTooHigh();

        uint256 oldLeverage = leverage;
        if (newLeverage == oldLeverage) revert NoChangeDetected();
        uint256 newEffectiveCollateral = baseCollateral * newLeverage / 100;

        // adjust leverage
        if (newLeverage > oldLeverage) {
            // increase
            uint256 borrowCollateral = newEffectiveCollateral - effectiveCollateral;
            uint256 additionalBorrow = convertCollateralPrice(borrowCollateral);
            flMode = 1;

            ILendingPool(lendingPool).flashLoan(address(ILendingPool(lendingPool).loanToken()), additionalBorrow, "");
            _borrow(additionalBorrow);

            flMode = 0;
        } else if (newLeverage < oldLeverage) {
            // decrease
            uint256 repaidCollateral = effectiveCollateral - newEffectiveCollateral;
            uint256 amountOut = _swap(lendingPool.loanToken(), lendingPool.collateralToken(), repaidCollateral);

            uint256 repaidShares = convertBorrowAmountToShares(amountOut);
            lendingPool.repayByPosition(msg.sender, repaidShares);
            borrowShares -= repaidShares;
        }

        effectiveCollateral = newEffectiveCollateral;
        leverage = newLeverage;
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        setRiskInfo(effectiveCollateral, borrowAmount);
        _emitUpdatePosition();
    }

    function closePosition() external {
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        lendingPool.withdrawCollateralByPosition(address(this), effectiveCollateral);

        uint256 amountOut = _swap(lendingPool.collateralToken(), lendingPool.loanToken(), effectiveCollateral);
        lendingPool.repayByPosition(msg.sender, borrowShares);

        uint256 diffAmount = amountOut - borrowAmount;
        IERC20(lendingPool.loanToken()).transfer(msg.sender, amount);

        borrowShares = 0;
        baseCollateral = 0;
        effectiveCollateral = 0;
        leverage = 100;
        liquidationPrice = 0;
        health = 0;
        ltv = 0;
        _emitUpdatePosition();
    }
}
