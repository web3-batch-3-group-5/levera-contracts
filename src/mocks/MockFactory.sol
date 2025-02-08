// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockFactory {
    error MockAlreadyCreated();
    error MockNotFound();

    mapping(string => address) public tokens;
    mapping(string => address) public aggregators;

    function createMock(string calldata name, string calldata symbol, uint8 decimals, int256 price)
        public
        returns (address tokenAddress, address aggregatorAddress)
    {
        if (tokens[name] != address(0) || aggregators[name] != address(0)) revert MockAlreadyCreated();

        // Deploy new MockERC20Token
        MockERC20 token = new MockERC20(name, symbol);
        tokens[name] = address(token);

        // Deploy new MockV3Aggregator
        MockV3Aggregator aggregator = new MockV3Aggregator(decimals, price);
        aggregators[name] = address(aggregator);

        return (address(token), address(aggregator));
    }

    function storeMock(string calldata name, address _mockToken, address _mockAggregator) public {
        if (tokens[name] != address(0) || aggregators[name] != address(0)) revert MockAlreadyCreated();

        tokens[name] = _mockToken;
        aggregators[name] = _mockAggregator;
    }

    function discardMock(string calldata name) public {
        if (tokens[name] == address(0) || aggregators[name] == address(0)) revert MockNotFound();

        delete tokens[name];
        delete aggregators[name];
    }
}
