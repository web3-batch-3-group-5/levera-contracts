// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";

/*
 * We cannot interact with Flame Block Explorer hence it's important to create REPL file for setup
 * 1) Create MockAggregator and pair token - aggregator
 * 2) Minting
 */
contract REPLMockDeploy is Script {
    struct MockConfig {
        address contractAddr;
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
    }

    MockConfig[] private mockTokens;
    address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x82069D54DF7fB4d9D9d8B35e2BecA6FE6aBAdF87;
    address private constant MOCK_FACTORY_ADDR = 0xc7247F78c46152Ecc3184BA51B8604D6eb807200;

    constructor() {
        mockTokens.push(MockConfig(0xEfd02292Cb87CCeeE1267141deef959cF739F9A9, "Mock USD Coin", "laUSDC", 6, 1e6));
        mockTokens.push(
            MockConfig(0x84f529597e077130f7133fa58a675FA32ccc9577, "Mock Wrapped Bitcoin", "laWBTC", 8, 100_000e8)
        );
        mockTokens.push(
            MockConfig(0xc004D73765391768C584001fdF2f491783F84EC7, "Mock Wrapped Ethereum", "laWETH", 18, 2_500e18)
        );
    }

    function setupFlameMockUniswapRouter() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        MockFactory mockFactory = MockFactory(MOCK_FACTORY_ADDR);
        MockUniswapRouter mockUniswapRouter = MockUniswapRouter(MOCK_UNISWAP_ROUTER_ADDR);

        console.log("================ Configure Mock in Router =================");
        for (uint256 i = 0; i < mockTokens.length; i++) {
            MockConfig memory token = mockTokens[i];
            mockFactory.storeMockToken(token.name, token.symbol, token.contractAddr);
            address priceFeed = mockFactory.createMockAggregator(token.name, token.symbol, token.decimals, token.price);
            mockUniswapRouter.setPriceFeed(token.contractAddr, priceFeed);
            console.log(
                string(
                    abi.encodePacked("[", token.symbol, "] Token: ", token.contractAddr, ", Aggregator: ", priceFeed)
                )
            );
        }
        console.log("===========================================================");
        vm.stopBroadcast();
    }

    function run() external {
        setupFlameMockUniswapRouter();
    }
}
