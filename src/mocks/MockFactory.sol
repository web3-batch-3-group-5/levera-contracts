// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockFactory {
    mapping(string => address) tokens;
    mapping(string => address) aggregators;

    function deployMock(string memory name, string memory symbol, uint8 decimals, int256 price)
        public
        returns (address tokenAddress, address aggregatorAddress)
    {
        string memory key = string(abi.encodePacked(name));

        // Deploy new MockERC20Token
        MockERC20 token = new MockERC20(name, symbol);
        tokens[key] = address(token);

        // Deploy new MockV3Aggregator
        MockV3Aggregator aggregator = new MockV3Aggregator(decimals, price);
        aggregators[key] = address(aggregator);

        return (address(token), address(aggregator));
    }
}
