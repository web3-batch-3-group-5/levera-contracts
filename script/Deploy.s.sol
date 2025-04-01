// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {Vault} from "../src/Vault.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract Deploy is Script {
    function deployFactory() public {
        vm.startBroadcast();
        address owner = vm.envAddress("OWNER_ADDRESS");
        // ISwapRouter uniswapRouter = ISwapRouter(0x0DA34E6C6361f5B8f5Bdb6276fEE16dD241108c8);
        address mockUniswapRouterAddr = address(new MockUniswapRouter());
        address vaultAddr = address(new Vault(owner));
        address lendingPoolFactoryAddr = address(new LendingPoolFactory(mockUniswapRouterAddr, vaultAddr));
        address positionFactoryAddr = address(new PositionFactory());
        address mockFactoryAddr = address(new MockFactory());
        // address laDAI = address(new MockERC20("Mock DAI", "laDAI", 18));
        // address laUSDC = address(new MockERC20("Mock USD Coin", "laUSDC", 6));
        // address laUSDT = address(new MockERC20("Mock USD Token", "laUSDT", 6));
        // address laWBTC = address(new MockERC20("Mock Wrapped Bitcoin", "laWBTC", 8));
        // address laWETH = address(new MockERC20("Mock Wrapped Ethereum", "laWETH", 18));

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock Uniswap Router deployed at:", mockUniswapRouterAddr);
        console.log("Mock Vault deployed at:", vaultAddr);
        console.log("Lending Pool Factory deployed at:", lendingPoolFactoryAddr);
        console.log("Position Factory deployed at:", positionFactoryAddr);
        console.log("Mock Factory deployed at:", mockFactoryAddr);
        // console.log("Mock laDAI deployed at:", laDAI);
        // console.log("Mock laUSDC deployed at:", laUSDC);
        // console.log("Mock laUSDT deployed at:", laUSDT);
        // console.log("Mock laWBTC deployed at:", laWBTC);
        // console.log("Mock laWETH deployed at:", laWETH);
        console.log("==============================================================");
        vm.stopBroadcast();
    }

    function run() external {
        return deployFactory();
    }
}
