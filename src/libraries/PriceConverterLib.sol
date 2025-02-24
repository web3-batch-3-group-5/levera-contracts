// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

library PriceConverterLib {
    error NegativeAnswer();

    uint256 constant PRECISION = 1e18; // ETH Precision

    function getPrice(AggregatorV2V3Interface dataFeed) public view returns (uint256) {
        (, int256 answer,,,) = dataFeed.latestRoundData();
        if (answer < 0) revert NegativeAnswer();

        // Normalize price to 18 decimals
        return uint256(answer) * PRECISION / (10 ** dataFeed.decimals());
    }

    function getConversionRate(
        uint256 amountIn,
        AggregatorV2V3Interface dataFeedIn,
        AggregatorV2V3Interface dataFeedOut
    ) public view returns (uint256 amountOut) {
        uint256 priceFeedIn = getPrice(dataFeedIn); // WBTC/USD
        uint256 priceFeedOut = getPrice(dataFeedOut); // USDC/USD

        // Normalize amountIn to 18 decimals
        uint256 amountInNormalized = amountIn * (10 ** (18 - dataFeedIn.decimals()));

        // Convert value
        uint256 amountOutNormalized = (amountInNormalized * priceFeedIn) / priceFeedOut;

        // Convert back to the correct decimals of the output token
        return amountOutNormalized / (10 ** (18 - dataFeedOut.decimals()));
    }
}
