// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool, ISwapRouter} from "./interfaces/ILendingPool.sol";

contract Position {
    error InvalidToken();

    // Uniswap Router
    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address public immutable lendingPool;
    address public immutable collateralToken;
    address public immutable loanToken;

    uint256 private flMode; // 0= no, 1=add leverage, 2=remove leverage, 3=close position

    constructor(address _lendingPool, address _collateralToken, address _loanToken) {
        lendingPool = _lendingPool;
        collateralToken = _collateralToken;
        loanToken = _loanToken;
    }

    function addLeverage(uint256 amount, uint256 debt) external {
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);

        flMode = 1;

        ILendingPool(lendingPool).flashLoan(address(loanToken), debt, "");

        flMode = 0;
    }

    function onFlashLoan(address token, uint256 amount, bytes calldata) external {
        if (token != loanToken) revert InvalidToken();

        if (flMode == 1) _flAddLeverage(token, amount);

        // repay flashloan
        IERC20(token).approve(address(lendingPool), amount);
    }

    function _flAddLeverage(address token, uint256 amount) internal {
        ISwapRouter(router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: collateralToken,
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 collateralAmount = IERC20(collateralToken).balanceOf(address(this));

        IERC20(collateralToken).approve(address(lendingPool), collateralAmount);
        ILendingPool(lendingPool).supply(collateralAmount);

        ILendingPool(lendingPool).borrow(amount);
    }
}
