// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast();
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory();
        // MockFactory mockFactory = new MockFactory();

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        // console.log("Mock Factory deployed at:", address(mockFactory));
        console.log("==============================================================");

        vm.stopBroadcast();
    }
}
