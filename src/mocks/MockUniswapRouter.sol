// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {ISwapRouter} from "../interfaces/ILendingPool.sol";

contract MockUniswapRouter is ISwapRouter {
    mapping(address => MockV3Aggregator) public priceFeeds;

    function setPriceFeed(address token, address priceFeed) external {
        priceFeeds[token] = MockV3Aggregator(priceFeed);
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        MockV3Aggregator priceFeedIn = priceFeeds[params.tokenIn];
        MockV3Aggregator priceFeedOut = priceFeeds[params.tokenOut];

        require(address(priceFeedIn) != address(0), "No price feed for tokenIn");
        require(address(priceFeedOut) != address(0), "No price feed for tokenOut");

        uint256 priceIn = uint256(priceFeedIn.latestAnswer());
        uint256 priceOut = uint256(priceFeedOut.latestAnswer());

        require(priceIn > 0 && priceOut > 0, "Invalid token price");

        // Calculate output amount based on price ratio
        amountOut = (params.amountIn * priceIn) / priceOut;

        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");
    }
}
