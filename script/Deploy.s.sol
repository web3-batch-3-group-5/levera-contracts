// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockWBTC} from "../src/mocks/MockWBTC.sol";

contract LendingScript is Script {
    LendingPool public lendingPool;
    MockUSDC public mockUSDC;
    MockWBTC public mockWBTC;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the mock USDC contract
        mockUSDC = new MockUSDC();
        mockWBTC = new MockWBTC();

        // Deploy the LendingPool contract with the address of the mock USDC and WBTC contract
        lendingPool = new LendingPool(mockUSDC, mockWBTC);

        vm.stopBroadcast();
    }
}
