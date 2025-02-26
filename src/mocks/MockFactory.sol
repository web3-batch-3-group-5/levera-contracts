// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockFactory {
    error MockAlreadyCreated();
    error MockNotFound();

    mapping(bytes32 => address) public tokens;
    mapping(bytes32 => address) public aggregators;

    function createMockToken(string calldata name, string calldata symbol, uint8 decimals) public returns (address) {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (tokens[id] != address(0)) revert MockAlreadyCreated();

        // Deploy new MockERC20Token
        MockERC20 token = new MockERC20(name, symbol, decimals);
        tokens[id] = address(token);

        return address(token);
    }

    function createMockAggregator(string calldata name, string calldata symbol, uint8 decimals, int256 price)
        public
        returns (address)
    {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (aggregators[id] != address(0)) revert MockAlreadyCreated();

        // Deploy new MockV3Aggregator
        MockV3Aggregator aggregator = new MockV3Aggregator(decimals, price);
        aggregators[id] = address(aggregator);

        return address(aggregator);
    }

    function storeMockToken(string calldata name, string calldata symbol, address _mockToken) public {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (tokens[id] != address(0)) revert MockAlreadyCreated();

        tokens[id] = _mockToken;
    }

    function storeMockAggregator(string calldata name, string calldata symbol, address _mockAggregator) public {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (aggregators[id] != address(0)) revert MockAlreadyCreated();

        aggregators[id] = _mockAggregator;
    }

    function discardMockToken(string calldata name, string calldata symbol) public {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (tokens[id] == address(0)) revert MockNotFound();

        delete tokens[id];
    }

    function discardMockAggregator(string calldata name, string calldata symbol) public {
        bytes32 id = keccak256(abi.encode(name, symbol));
        if (aggregators[id] == address(0)) revert MockNotFound();

        delete aggregators[id];
    }
}
