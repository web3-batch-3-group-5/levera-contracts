// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {Vault} from "../src/Vault.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";

contract Deploy is Script {
    function deployFactory() public {
        address owner = vm.envAddress("PUBLIC_KEY");
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));
        address mockUniswapRouterAddr = address(new MockUniswapRouter());
        address vaultAddr = address(new Vault(owner));
        address mockFactoryAddr = address(new MockFactory());
        address lendingPoolFactoryAddr = address(new LendingPoolFactory(mockUniswapRouterAddr, vaultAddr));
        address positionFactoryAddr = address(new PositionFactory());

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock Uniswap Router deployed at:", mockUniswapRouterAddr);
        console.log("Mock Vault deployed at:", vaultAddr);
        console.log("Mock Factory deployed at:", mockFactoryAddr);
        console.log("Lending Pool Factory deployed at:", lendingPoolFactoryAddr);
        console.log("Position Factory deployed at:", positionFactoryAddr);
        console.log("==============================================================");
        vm.stopBroadcast();
    }

    function run() external {
        return deployFactory();
    }
}
