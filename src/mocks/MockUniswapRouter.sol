// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {ISwapRouter} from "../interfaces/ILendingPool.sol";
import {PriceConverterLib} from "../libraries/PriceConverterLib.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockUniswapRouter is ISwapRouter {
    mapping(address => AggregatorV2V3Interface) public priceFeeds;

    function setPriceFeed(address token, address priceFeed) external {
        priceFeeds[token] = AggregatorV2V3Interface(priceFeed);
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        AggregatorV2V3Interface priceFeedIn = priceFeeds[params.tokenIn];
        AggregatorV2V3Interface priceFeedOut = priceFeeds[params.tokenOut];

        require(address(priceFeedIn) != address(0), "No price feed for tokenIn");
        require(address(priceFeedOut) != address(0), "No price feed for tokenOut");

        // Normalize price precision
        amountOut = PriceConverterLib.getConversionRate(params.amountIn, priceFeedIn, priceFeedOut);

        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        // Ensure sender has enough balance & allowance
        require(MockERC20(params.tokenIn).balanceOf(msg.sender) >= params.amountIn, "Insufficient Balance");
        require(
            MockERC20(params.tokenIn).allowance(msg.sender, address(this)) >= params.amountIn, "Insufficient Allowance"
        );

        MockERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        // Ensure contract has enough tokenOut for swap if DEX is connected
        // require(MockERC20(params.tokenOut).balanceOf(address(this)) >= amountOut, "Insufficient liquidity");
        MockERC20(params.tokenOut).mint(address(this), amountOut);

        // Transfer tokenOut to sender
        MockERC20(params.tokenOut).transfer(msg.sender, amountOut);
    }
}
