// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IVault, ISwapRouter} from "./interfaces/IVault.sol";
import {PositionStatus} from "./interfaces/IPosition.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {Vault} from "./Vault.sol";

contract Position {
    error InsufficientCollateral();
    error InsufficientMinimumLeverage();
    error LeverageTooHigh();
    error NoChangeDetected();
    error PositionAtRisk();
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error PositionAlreadyLiquidated();
    error PositionHealthy();

    address public immutable owner;
    address public immutable creator;
    ILendingPool public immutable lendingPool;
    uint256 public baseCollateral; // Represents the initial collateral amount.
    uint256 public effectiveCollateral; // Represents the total collateral after including borrowed collateral.
    uint256 public borrowShares;
    uint256 public leverage = 100;
    uint256 public liquidationPrice;
    uint256 public health;
    uint256 public ltv;
    uint256 public lastUpdated;
    uint8 public status; // 0= open, 1= closed, 2=liquidated

    uint256 private flMode; // 0= no, 1=add leverage, 2=remove leverage, 3=close position

    constructor(address _lendingPool, address _creator) {
        owner = msg.sender;
        creator = _creator;
        lendingPool = ILendingPool(_lendingPool);
    }

    modifier onlyCreator() {
        if (msg.sender != creator) revert Unauthorized();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function _emitUpdatePosition() internal {
        lastUpdated = block.timestamp;

        emit EventLib.UserPosition(
            address(this),
            address(lendingPool),
            creator,
            baseCollateral,
            effectiveCollateral,
            borrowShares,
            leverage,
            liquidationPrice,
            health,
            ltv,
            status
        );
    }

    function _emitSupplyCollateral() internal {
        emit EventLib.SupplyCollateral(
            address(lendingPool), creator, address(this), effectiveCollateral, borrowShares, leverage
        );
    }

    function _emitWithdrawCollateral() internal {
        emit EventLib.WithdrawCollateral(
            address(lendingPool), creator, address(this), effectiveCollateral, borrowShares, leverage
        );
    }

    function _emitBorrow() internal {
        emit EventLib.Borrow(address(lendingPool), creator, address(this), effectiveCollateral, borrowShares, leverage);
    }

    function _emitRepay() internal {
        emit EventLib.Repay(address(lendingPool), creator, address(this), effectiveCollateral, borrowShares, leverage);
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

    function setRiskInfo() public {
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        uint256 effectiveCollateralPrice = convertCollateralPrice(effectiveCollateral);

        liquidationPrice = lendingPool.getLiquidationPrice(effectiveCollateral, borrowAmount);
        health = lendingPool.getHealth(effectiveCollateralPrice, borrowAmount);
        ltv = lendingPool.getLTV(effectiveCollateralPrice, borrowAmount);
    }

    function addCollateral(uint256 amount) public onlyCreator {
        IERC20(lendingPool.collateralToken()).transferFrom(msg.sender, address(this), amount);
        baseCollateral += amount;
        leverage = effectiveCollateral * 100 / baseCollateral;
        _supplyCollateral(amount);

        setRiskInfo();
        _emitUpdatePosition();
    }

    function _supplyCollateral(uint256 amount) internal {
        effectiveCollateral += amount;

        IERC20(lendingPool.collateralToken()).approve(address(lendingPool), amount);
        lendingPool.supplyCollateralByPosition(address(this), amount);

        _emitSupplyCollateral();
    }

    function withdrawCollateral(uint256 amount) public onlyCreator {
        if (amount == 0) revert ZeroAmount();
        if (amount > baseCollateral) revert InsufficientCollateral();
        baseCollateral -= amount;
        effectiveCollateral -= amount;
        leverage = effectiveCollateral * 100 / baseCollateral;
        _checkHealth();

        lendingPool.withdrawCollateralByPosition(address(this), amount);
        setRiskInfo();

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
        setRiskInfo();
    }

    function openPosition(uint256 _baseCollateral, uint256 _leverage) public onlyOwner {
        address collateralToken = lendingPool.collateralToken();
        baseCollateral = _baseCollateral;
        leverage = _leverage;
        IERC20(collateralToken).transferFrom(msg.sender, address(this), _baseCollateral);

        flMode = 1;

        uint256 borrowCollateral = _baseCollateral * (_leverage - 100) / 100;
        IVault(lendingPool.vault()).flashLoan(collateralToken, borrowCollateral, "");

        flMode = 0;

        setRiskInfo();
        _emitUpdatePosition();
    }

    function onFlashLoan(address token, uint256 amount, bytes calldata) external {
        if (flMode == 1) _flAddLeverage(token, amount);

        // repay flashloan
        IERC20(token).approve(lendingPool.vault(), amount);
    }

    function _flAddLeverage(address token, uint256 amount) internal {
        uint256 totalCollateral = IERC20(token).balanceOf(address(this));
        _supplyCollateral(totalCollateral);
        effectiveCollateral = totalCollateral;

        uint256 borrowAmount = convertCollateralPrice(amount);
        _borrow(borrowAmount);

        _swap(lendingPool.loanToken(), token, borrowAmount);
    }

    function _swap(address tokenIn, address tokenOut, uint256 amount) internal returns (uint256) {
        address routerAddr = lendingPool.router();
        IERC20(tokenIn).approve(routerAddr, amount);

        ISwapRouter(routerAddr).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this));
        return amountOut;
    }

    function _checkHealth() internal view {
        uint256 effectiveCollateralPrice = convertCollateralPrice(effectiveCollateral);
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        uint256 healthFactor = (effectiveCollateralPrice * lendingPool.ltp()) / borrowAmount;

        if (healthFactor < 1) revert PositionAtRisk();
    }

    function updateLeverage(uint256 newLeverage) external onlyCreator {
        if (newLeverage < 100) revert InsufficientMinimumLeverage();
        if (newLeverage > 500) revert LeverageTooHigh();

        uint256 oldLeverage = leverage;
        if (newLeverage == oldLeverage) revert NoChangeDetected();
        uint256 newEffectiveCollateral = baseCollateral * newLeverage / 100;
        leverage = newLeverage;

        // adjust leverage
        if (newLeverage > oldLeverage) {
            // increase
            uint256 borrowCollateral = newEffectiveCollateral - effectiveCollateral;
            flMode = 1;

            IVault(lendingPool.vault()).flashLoan(lendingPool.collateralToken(), borrowCollateral, "");

            flMode = 0;
        } else if (newLeverage < oldLeverage) {
            // decrease
            uint256 repaidCollateral = effectiveCollateral - newEffectiveCollateral;
            uint256 amountOut = _swap(lendingPool.collateralToken(), lendingPool.loanToken(), repaidCollateral);

            uint256 repaidShares = convertBorrowAmountToShares(amountOut);
            IERC20(lendingPool.loanToken()).approve(address(lendingPool), amountOut);
            lendingPool.repayByPosition(address(this), repaidShares);
            borrowShares -= repaidShares;
            _emitRepay();
        }

        effectiveCollateral = newEffectiveCollateral;
        setRiskInfo();
        _emitUpdatePosition();
    }

    function _resetPosition(uint8 _status) internal {
        borrowShares = 0;
        baseCollateral = 0;
        effectiveCollateral = 0;
        leverage = 100;
        liquidationPrice = 0;
        health = 0;
        ltv = 0;
        status = _status;
        _emitUpdatePosition();
    }

    function closePosition() external onlyOwner returns (uint256) {
        lendingPool.withdrawCollateralByPosition(address(this), effectiveCollateral);
        _emitWithdrawCollateral();

        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        uint256 amountOut = _swap(lendingPool.collateralToken(), lendingPool.loanToken(), effectiveCollateral);
        IERC20(lendingPool.loanToken()).approve(address(lendingPool), amountOut);
        lendingPool.repayByPosition(address(this), borrowShares);
        _emitRepay();

        uint256 diffAmount = amountOut - borrowAmount;
        IERC20(lendingPool.loanToken()).approve(address(this), diffAmount);
        IERC20(lendingPool.loanToken()).transfer(msg.sender, diffAmount);

        _resetPosition(1);

        return diffAmount;
    }

    function liquidatePosition() external onlyOwner returns (uint256) {
        if (status == 2) revert PositionAlreadyLiquidated();

        setRiskInfo();

        // Ensure the position is at risk
        if (health > 0 && ltv < 100) revert PositionHealthy();

        lendingPool.withdrawCollateralByPosition(address(this), effectiveCollateral);
        _emitWithdrawCollateral();

        // Transfer remaining collateral to the owner (if any remaining)
        uint256 borrowAmount = convertBorrowSharesToAmount(borrowShares);
        uint256 amountOut = _swap(lendingPool.collateralToken(), lendingPool.loanToken(), effectiveCollateral);

        IERC20(lendingPool.loanToken()).approve(address(lendingPool), 0);
        IERC20(lendingPool.loanToken()).approve(address(lendingPool), amountOut);
        lendingPool.repayByPosition(address(this), borrowShares);
        _emitRepay();

        uint256 diffAmount = amountOut - borrowAmount;
        if (diffAmount > 0) {
            IERC20(lendingPool.loanToken()).approve(address(this), diffAmount);
            IERC20(lendingPool.loanToken()).transfer(msg.sender, diffAmount);
        }

        _resetPosition(2);

        return diffAmount;
    }

    function repay(uint256 amount) external onlyCreator {
        if (amount == 0) revert ZeroAmount();

        IERC20(lendingPool.loanToken()).transferFrom(msg.sender, address(this), amount);
        IERC20(lendingPool.loanToken()).approve(address(lendingPool), amount);

        uint256 shares = convertBorrowAmountToShares(amount);
        lendingPool.repayByPosition(address(this), shares);

        borrowShares -= shares;

        setRiskInfo();
        _emitRepay();
    }
}
