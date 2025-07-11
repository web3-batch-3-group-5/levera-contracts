// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {ISwapRouter} from "../interfaces/IVault.sol";
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
        MockERC20(params.tokenOut).mint(address(this), amountOut);

        // Transfer tokenOut to recipient
        MockERC20(params.tokenOut).transfer(params.recipient, amountOut);
    }

    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        // For simplicity, mock multi-hop as single hop using first and last token
        address tokenIn = address(bytes20(params.path[0:20]));
        address tokenOut = address(bytes20(params.path[params.path.length - 20:]));

        AggregatorV2V3Interface priceFeedIn = priceFeeds[tokenIn];
        AggregatorV2V3Interface priceFeedOut = priceFeeds[tokenOut];

        require(address(priceFeedIn) != address(0), "No price feed for tokenIn");
        require(address(priceFeedOut) != address(0), "No price feed for tokenOut");

        amountOut = PriceConverterLib.getConversionRate(params.amountIn, priceFeedIn, priceFeedOut);
        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        MockERC20(tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        MockERC20(tokenOut).mint(address(this), amountOut);
        MockERC20(tokenOut).transfer(params.recipient, amountOut);
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        AggregatorV2V3Interface priceFeedIn = priceFeeds[params.tokenIn];
        AggregatorV2V3Interface priceFeedOut = priceFeeds[params.tokenOut];

        require(address(priceFeedIn) != address(0), "No price feed for tokenIn");
        require(address(priceFeedOut) != address(0), "No price feed for tokenOut");

        // Calculate required input amount
        amountIn = PriceConverterLib.getConversionRate(params.amountOut, priceFeedOut, priceFeedIn);
        require(amountIn <= params.amountInMaximum, "Excessive input amount");

        MockERC20(params.tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(params.tokenOut).mint(address(this), params.amountOut);
        MockERC20(params.tokenOut).transfer(params.recipient, params.amountOut);
    }

    function exactOutput(ExactOutputParams calldata params) external payable override returns (uint256 amountIn) {
        // For simplicity, mock multi-hop as single hop using first and last token
        address tokenIn = address(bytes20(params.path[params.path.length - 20:]));
        address tokenOut = address(bytes20(params.path[0:20]));

        AggregatorV2V3Interface priceFeedIn = priceFeeds[tokenIn];
        AggregatorV2V3Interface priceFeedOut = priceFeeds[tokenOut];

        require(address(priceFeedIn) != address(0), "No price feed for tokenIn");
        require(address(priceFeedOut) != address(0), "No price feed for tokenOut");

        amountIn = PriceConverterLib.getConversionRate(params.amountOut, priceFeedOut, priceFeedIn);
        require(amountIn <= params.amountInMaximum, "Excessive input amount");

        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).mint(address(this), params.amountOut);
        MockERC20(tokenOut).transfer(params.recipient, params.amountOut);
    }
}
