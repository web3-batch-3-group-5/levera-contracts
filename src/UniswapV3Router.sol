// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ISwapRouter} from "./interfaces/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter as IUniswapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IPeripheryImmutableState} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

contract UniswapV3Router is ISwapRouter {
    using SafeERC20 for IERC20;

    IUniswapRouter public immutable uniswapRouter;
    address public immutable WETH9;

    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapRouter(_uniswapRouter);
        WETH9 = IPeripheryImmutableState(_uniswapRouter).WETH9();
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        // Transfer tokens from sender to this contract
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // Approve Uniswap router to spend tokens
        IERC20(params.tokenIn).approve(address(uniswapRouter), params.amountIn);

        // Convert to Uniswap's ExactInputSingleParams
        IUniswapRouter.ExactInputSingleParams memory uniswapParams = IUniswapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            fee: params.fee,
            recipient: params.recipient,
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        });

        // Execute swap
        amountOut = uniswapRouter.exactInputSingle(uniswapParams);
    }

    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        // Extract tokenIn from path (first 20 bytes)
        address tokenIn = address(bytes20(params.path[0:20]));

        // Transfer tokens from sender to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        // Approve Uniswap router to spend tokens
        IERC20(tokenIn).approve(address(uniswapRouter), params.amountIn);

        // Convert to Uniswap's ExactInputParams
        IUniswapRouter.ExactInputParams memory uniswapParams = IUniswapRouter.ExactInputParams({
            path: params.path,
            recipient: params.recipient,
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum
        });

        // Execute swap
        amountOut = uniswapRouter.exactInput(uniswapParams);
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        // Transfer max tokens from sender to this contract
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountInMaximum);

        // Approve Uniswap router to spend tokens
        IERC20(params.tokenIn).approve(address(uniswapRouter), params.amountInMaximum);

        // Convert to Uniswap's ExactOutputSingleParams
        IUniswapRouter.ExactOutputSingleParams memory uniswapParams = IUniswapRouter.ExactOutputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            fee: params.fee,
            recipient: params.recipient,
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        });

        // Execute swap
        amountIn = uniswapRouter.exactOutputSingle(uniswapParams);

        // Refund unused tokens
        if (params.amountInMaximum > amountIn) {
            IERC20(params.tokenIn).safeTransfer(msg.sender, params.amountInMaximum - amountIn);
        }
    }

    function exactOutput(ExactOutputParams calldata params) external payable override returns (uint256 amountIn) {
        // Extract tokenIn from path (last 20 bytes)
        address tokenIn = address(bytes20(params.path[params.path.length - 20:]));

        // Transfer max tokens from sender to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountInMaximum);

        // Approve Uniswap router to spend tokens
        IERC20(tokenIn).approve(address(uniswapRouter), params.amountInMaximum);

        // Convert to Uniswap's ExactOutputParams
        IUniswapRouter.ExactOutputParams memory uniswapParams = IUniswapRouter.ExactOutputParams({
            path: params.path,
            recipient: params.recipient,
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum
        });

        // Execute swap
        amountIn = uniswapRouter.exactOutput(uniswapParams);

        // Refund unused tokens
        if (params.amountInMaximum > amountIn) {
            IERC20(tokenIn).safeTransfer(msg.sender, params.amountInMaximum - amountIn);
        }
    }
}
