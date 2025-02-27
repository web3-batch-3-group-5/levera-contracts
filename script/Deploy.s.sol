// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LaUSDC} from "../src/mocks/LaUSDC.sol";
import {LaWBTC} from "../src/mocks/LaWBTC.sol";
import {LaWETH} from "../src/mocks/LaWETH.sol";
import {LaUSDT} from "../src/mocks/LaUSDT.sol";
import {LaDAI} from "../src/mocks/LaDAI.sol";

contract Deploy is Script {
    function deployFactory() public {
        vm.startBroadcast();
        // ISwapRouter uniswapRouter = ISwapRouter(0x0DA34E6C6361f5B8f5Bdb6276fEE16dD241108c8);

        // Arbitrum Sepolia
        // address mockUniswapRouter = 0xb2defA89d4D2F0AD66A9A8d28486F1781EEa7c2A;
        // Flame Testnet
        // address mockUniswapRouter = 0x82069D54DF7fB4d9D9d8B35e2BecA6FE6aBAdF87;
        MockUniswapRouter mockUniswapRouter = new MockUniswapRouter();
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter));
        PositionFactory positionFactory = new PositionFactory();
        // MockFactory mockFactory = new MockFactory();
        // LaUSDC laUSDC = new LaUSDC();
        // LaWBTC laWBTC = new LaWBTC();
        // LaWETH laWETH = new LaWETH();
        // LaDAI laDAI = new LaDAI();
        // LaUSDT laUSDT = new LaUSDT();

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock Uniswap Router deployed at:", address(mockUniswapRouter));
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Position Factory deployed at:", address(positionFactory));
        // console.log("Mock Factory deployed at:", address(mockFactory));
        // console.log("Mock laUSDC deployed at:", address(laUSDC));
        // console.log("Mock laWBTC deployed at:", address(laWBTC));
        // console.log("Mock laWETH deployed at:", address(laWETH));
        // console.log("Mock laDAI deployed at:", address(laDAI));
        // console.log("Mock laUSDT deployed at:", address(laUSDT));
        console.log("==============================================================");

        vm.stopBroadcast();
    }

    function run() external {
        return deployFactory();
    }
}
