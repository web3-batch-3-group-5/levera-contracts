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

    // Uniswap Router
    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address public immutable owner;
    address public immutable creator;
    ILendingPool public immutable lendingPool;
    uint256 public baseCollateral; // Represents the initial collateral amount.
    uint256 public effectiveCollateral; // Represents the total collateral after including borrowed collateral.
    uint256 public borrowShares;
    uint8 public leverage;
    uint256 public liquidationPrice;
    uint256 public health;
    uint256 public ltv;
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
            leverage,
            liquidationPrice,
            health,
            ltv
        );
    }

    function _emitSupplyCollateral(string memory action) internal {
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

    function _emitWithdrawCollateral(string memory action) internal {
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

    function _emitBorrow(string memory action) internal {
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

    function _emitRepay(string memory action) internal {
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

    function convertCollateral(uint256 effectiveCollateralAmount) public view returns (uint256 amount) {
        return PriceConverterLib.getConversionRate(
            effectiveCollateralAmount,
            AggregatorV2V3Interface(lendingPool.collateralTokenUsdDataFeed()),
            AggregatorV2V3Interface(lendingPool.loanTokenUsdDataFeed())
        );
    }

    function initialization(uint256 _baseCollateral, uint8 _leverage) external {
        baseCollateral = _baseCollateral;
        leverage = _leverage;
        effectiveCollateral = _baseCollateral * leverage;

        uint256 effectiveCollateralPrice = convertCollateral(effectiveCollateral);
        uint256 borrowAmount = convertCollateral(baseCollateral * (_leverage - 1));

        borrowShares = (borrowAmount * lendingPool.totalSupplyAssets()) / lendingPool.totalSupplyShares();
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

        _isHealthy();
        lendingPool.withdrawCollateralByPosition(address(this), amount);

        _emitUpdatePosition();
        _emitWithdrawCollateral();

        IERC20(collateralToken).transfer(msg.sender, amount);
    }

    function _borrow(uint256 amount) internal {
        uint256 shares = lendingPool.borrowByPosition(address(this), amount); // Now correctly returns shares
        borrowShares += shares; // ✅ Updates borrowShares
        _isHealthy();
        _emitBorrow();
    }

    function openPosition(uint256 amount, uint256 debt) external {
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
        ISwapRouter(router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: ILendingPool(lendingPool).collateralToken(),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 amountOut = IERC20(ILendingPool(lendingPool).collateralToken()).balanceOf(address(this));
        effectiveCollateral += amountOut;

        IERC20(lendingPool.collateralToken()).approve(address(lendingPool), amountOut);
        lendingPool.supplyCollateralByPosition(address(this), amountOut);

        _emitSupplyCollateral();
    }

    function _isHealthy() internal view {
        uint256 collateral = convertCollateral(baseCollateral);

        uint256 borrowAmount = lendingPool.totalBorrowShares() == 0
            ? 0
            : (borrowShares * lendingPool.totalBorrowAssets()) / lendingPool.totalBorrowShares();
        // Ensure borrowed doesn't exceed collateral before subtraction
        if (borrowAmount > collateral) revert InsufficientCollateral();

        uint256 allowedBorrowAmount = (collateral - borrowAmount) * ltv / 100;
        if (borrowAmount > allowedBorrowAmount) revert InsufficientCollateral();
    }
}
