// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    uint256 constant PRECISION = 1e18; // ETH Precision

    function getPrice(AggregatorV2V3Interface dataFeed) public view returns (uint256) {
        (, int256 answer,,,) = dataFeed.latestRoundData();
        if (answer < 0) revert NegativeAnswer();
        return uint256(answer) * PRECISION / (10 ** dataFeed.decimals());
    }

    function getConversionRate(
        uint256 amountIn,
        AggregatorV2V3Interface dataFeedIn,
        AggregatorV2V3Interface dataFeedOut
    ) public view returns (uint256 amountOut) {
        uint256 priceFeedIn = getPrice(dataFeedIn);
        uint256 priceFeedOut = getPrice(dataFeedOut);

        return (amountIn * priceFeedIn) / priceFeedOut;
    }
}
