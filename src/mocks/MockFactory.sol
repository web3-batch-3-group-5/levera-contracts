// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockFactory {
    mapping(bytes32 => address) tokens;
    mapping(bytes32 => address) aggregators;

    function deployMock(string memory name, string memory symbol, uint8 decimals, int256 price)
        public
        returns (address tokenAddress, address aggregatorAddress)
    {
        bytes32 key = keccak256(abi.encodePacked(name));

        // Deploy new MockERC20Token
        MockERC20 token = new MockERC20(name, symbol);
        tokens[key] = address(token);

        // Deploy new MockV3Aggregator
        MockV3Aggregator aggregator = new MockV3Aggregator(decimals, price);
        aggregators[key] = address(aggregator);

        console2.log(string(abi.encodePacked("Deployed Mock Token for ", symbol, " at: ")), address(token));
        console2.log(string(abi.encodePacked("Deployed Mock Aggregator for ", symbol, " at: ")), address(aggregator));

        return (address(token), address(aggregator));
    }

    // Getter functions to retrieve stored mock addresses
    function getMockToken(string memory name) external view returns (address) {
        return tokens[keccak256(abi.encodePacked(name))];
    }

    function getMockAggregator(string memory name) external view returns (address) {
        return aggregators[keccak256(abi.encodePacked(name))];
    }
}
