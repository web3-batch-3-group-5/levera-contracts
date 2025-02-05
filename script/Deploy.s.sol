// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockWBTC} from "../src/mocks/MockWBTC.sol";
import {LendingPool} from "../src/LendingPool.sol";

contract LendingScript is Script {
    LendingPool public lendingPool;

    uint8 public DECIMALS = 8;
    int64 public constant WBTC_USD_PRICE = 1e13;
    int64 public constant USDC_USD_PRICE = 1e8;

    function run() public {
        vm.startBroadcast();

        // Deploy the mock USDC and WBTC contract
        // MockV3Aggregator usdcAggregator = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        // MockV3Aggregator wbtcAggregator = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);
        // IERC20 mockUSDC = new MockUSDC();
        // IERC20 mockWBTC = new MockWBTC();
        MockV3Aggregator usdcAggregator = MockV3Aggregator(0x43E328A3CB461426F26FBa0eca129FBb990cbC97);
        MockV3Aggregator wbtcAggregator = MockV3Aggregator(0x16B7F93876b7Be59C4075017A8fF5A1c6D204304);
        IERC20 mockUSDC = IERC20(0x849Def4D000EEFC1c3834607ce9F4d9C5b24A670);
        IERC20 mockWBTC = IERC20(0x9B8918cABf1D4838d988F7d9D459c1ABE3Af3a6D);

        // Deploy the LendingPool contract with the address of the mock USDC and WBTC contract
        lendingPool = new LendingPool(mockUSDC, mockWBTC, usdcAggregator, wbtcAggregator);

        vm.stopBroadcast();
    }
}
