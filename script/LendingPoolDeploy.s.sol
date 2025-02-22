// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {PositionType} from "../src/interfaces/ILendingPool.sol";

contract LendingPoolDeploy is Script {
    LendingPool public lendingPool;

    uint8 public DECIMALS = 8;
    int64 public constant WBTC_USD_PRICE = 1e13;
    int64 public constant USDC_USD_PRICE = 1e8;

    function run() public {
        vm.startBroadcast();

        // Deploy the mock USDC and WBTC contract
        // MockV3Aggregator usdcAggregator = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        // MockV3Aggregator wbtcAggregator = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);
        // IERC20 mockUSDC = new MockERC20("usdc", "USDC");
        // IERC20 mockWBTC = new MockERC20("wbtc", "WBTC");

        // Sepolia Testnet
        // MockV3Aggregator usdcAggregator = MockV3Aggregator(0x43E328A3CB461426F26FBa0eca129FBb990cbC97);
        // MockV3Aggregator wbtcAggregator = MockV3Aggregator(0x16B7F93876b7Be59C4075017A8fF5A1c6D204304);
        // IERC20 mockUSDC = IERC20(0x849Def4D000EEFC1c3834607ce9F4d9C5b24A670);
        // IERC20 mockWBTC = IERC20(0x9B8918cABf1D4838d988F7d9D459c1ABE3Af3a6D);

        // Arbitrum Sepolia
        MockV3Aggregator usdcAggregator = MockV3Aggregator(0x74B59C6C38AEA54644527aA0c5f8f4796e777533);
        MockV3Aggregator wbtcAggregator = MockV3Aggregator(0x5e4695a76Dc81ECc041576d672Da1208d6d8922B);
        IERC20 mockUSDC = IERC20(0x919c586538EE34B87A12c584ba6463e7e12338E9);
        IERC20 mockWBTC = IERC20(0xe7d9E1dB89Ce03570CBA7f4C6Af80EC14a61d1db);
        uint8 liquidationThresholdPercentage = 80;
        uint8 interestRate = 5;
        address alice = makeAddr("alice");
        PositionType positionType = PositionType.LONG;
        lendingPool = new LendingPool(
            mockUSDC,
            mockWBTC,
            usdcAggregator,
            wbtcAggregator,
            liquidationThresholdPercentage,
            interestRate,
            positionType,
            alice
        );

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcAggregator));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcAggregator));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("==============================================================");

        // Arbitrum Sepolia Testnet
        // AggregatorV2V3Interface usdcAggregator = AggregatorV2V3Interface(0x0153002d20B96532C639313c2d54c3dA09109309);
        // AggregatorV2V3Interface wbtcAggregator = AggregatorV2V3Interface(0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69);
        // IERC20 usdc = IERC20(0xf3C3351D6Bd0098EEb33ca8f830FAf2a141Ea2E1);
        // IERC20 wbtc = IERC20(0x99C67FFF21329c3B0f6922b7Df00bAB8D96325c9);
        // lendingPool = new LendingPool(usdc, wbtc, usdcAggregator, wbtcAggregator);

        vm.stopBroadcast();
    }
}
