// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
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

        // Mock Contract
        MockV3Aggregator usdcAggregator = MockV3Aggregator(0x43E328A3CB461426F26FBa0eca129FBb990cbC97);
        MockV3Aggregator wbtcAggregator = MockV3Aggregator(0x16B7F93876b7Be59C4075017A8fF5A1c6D204304);
        IERC20 mockUSDC = IERC20(0x849Def4D000EEFC1c3834607ce9F4d9C5b24A670);
        IERC20 mockWBTC = IERC20(0x9B8918cABf1D4838d988F7d9D459c1ABE3Af3a6D);
        lendingPool = new LendingPool(mockUSDC, mockWBTC, usdcAggregator, wbtcAggregator);

        // Arbitrum Sepolia Testnet
        // AggregatorV2V3Interface usdcAggregator = AggregatorV2V3Interface(0x0153002d20B96532C639313c2d54c3dA09109309);
        // AggregatorV2V3Interface wbtcAggregator = AggregatorV2V3Interface(0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69);
        // IERC20 usdc = IERC20(0xf3C3351D6Bd0098EEb33ca8f830FAf2a141Ea2E1);
        // IERC20 wbtc = IERC20(0x99C67FFF21329c3B0f6922b7Df00bAB8D96325c9);
        // lendingPool = new LendingPool(usdc, wbtc, usdcAggregator, wbtcAggregator);

        vm.stopBroadcast();
    }
}
