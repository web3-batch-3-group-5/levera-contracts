// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool, ISwapRouter} from "./interfaces/ILendingPool.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";

contract Position {
    error InvalidToken();

    // Uniswap Router
    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address public immutable owner;
    address public immutable creator;
    address public immutable lendingPool;
    uint256 public baseCollateral; // Represents the initial collateral amount.
    uint256 public effectiveCollateral; // Represents the total collateral after including borrowed collateral.
    uint256 public borrowShare;
    uint8 public leverage;
    uint256 public liquidationPrice;
    uint256 public health;
    uint256 public ltv;
    uint256 public lastUpdated;

    uint256 private flMode; // 0= no, 1=add leverage, 2=remove leverage, 3=close position

    constructor(address _lendingPool) {
        lendingPool = _lendingPool;
    }

    function convertCollateral() public view returns (uint256 amount) {
        return PriceConverterLib.getConversionRate(
            effectiveCollateral,
            AggregatorV2V3Interface(ILendingPool(lendingPool).collateralTokenUsdDataFeed()),
            AggregatorV2V3Interface(ILendingPool(lendingPool).loanTokenUsdDataFeed())
        );
    }

    function initialization() {
        baseCollateral = _baseCollateral;
        leverage = _leverage;
        effectiveCollateral = effectiveCollateral * leverage;
        borrowShare = convertCollateral(effectiveCollateral) * (_leverage - 1);
    }

    function addCollateral(uint256 amount) {
        _supplyCollateral(amount);
        _updatePosition();
    }

    function _supplyCollateral(uint256 amount) {
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        baseCollateral += amount;

        lendingPool.supplyCollateralByPosition(address(this), amount);

        emit EventLib.SupplyCollateral(
            address(lendingPool), msg.sender, address(this), currPositionParams())
        );
    }

    function _borrow(uint256 amount) {
        uint256 shares = ILendingPool(lendingPool).borrowByPosition(address(this), amount);
        borrowShares += shares;
        _isHealthy();

        _updatePosition(onBehalf);
        emit EventLib.BorrowByPosition(address(lendingPool), msg.sender, address(this), currPositionParams())
    }

    function openPosition(uint256 amount, uint256 debt) external {
        _supplyCollateral(amount);
        
        flMode = 1;

        _borrow(debt);
        ILendingPool(lendingPool).flashLoan(address(ILendingPool(lendingPool).loanToken()), debt, "");

        flMode = 0;

        _updatePosition();
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

        IERC20(collateralToken).approve(address(lendingPool), collateral);
        ILendingPool(lendingPool).supplyCollateralByPosition(address(this), amountOut);

        emit EventLib.SupplyCollateral(
            address(lendingPool), msg.sender, address(this), currPositionParams())
        );
    }
}
