// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {LendingPool} from "../src/LendingPool.sol";

contract LendingScript is Script {
    LendingPool public lendingPool;

    uint8 public DECIMALS = 8;
    int64 public constant WBTC_USD_PRICE = 1e13;
    int64 public constant USDC_USD_PRICE = 1e8;
    uint256 public constant SUPPLY = 1000e18;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the mock USDC and WBTC contract
        MockV3Aggregator usdcAggregator = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        ERC20Mock mockUSDC = new ERC20Mock();
        mockUSDC.mint(msg.sender, SUPPLY);

        MockV3Aggregator wbtcAggregator = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);
        ERC20Mock mockWBTC = new ERC20Mock();
        mockWBTC.mint(msg.sender, SUPPLY);

        // Deploy the LendingPool contract with the address of the mock USDC and WBTC contract
        lendingPool = new LendingPool(mockUSDC, mockWBTC);

        vm.stopBroadcast();
    }
}
