// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";

contract Deploy is Script {
    function deployFactory() public {
        vm.startBroadcast();
        // ISwapRouter uniswapRouter = ISwapRouter(0x0DA34E6C6361f5B8f5Bdb6276fEE16dD241108c8);
        // MockUniswapRouter mockUniswapRouter = new MockUniswapRouter();
        address mockUniswapRouter = 0xA0DdB46FCB2Aa91E4107C692af9eF74Cd95a082b;
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter));
        PositionFactory positionFactory = new PositionFactory();
        // MockFactory mockFactory = new MockFactory();

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock Uniswap Router deployed at:", address(mockUniswapRouter));
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Position Factory deployed at:", address(positionFactory));
        // console.log("Mock Factory deployed at:", address(mockFactory));
        console.log("==============================================================");

        vm.stopBroadcast();
    }

    function run() external {
        return deployFactory();
    }
}
