// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";

/*
 * Interactively create MockToken, MockAggregator and pair token - aggregator
 * 2) Minting
 */
contract REPLMockToken is Script {
    struct MockTokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
        uint256 supplyAmount;
    }

    address MOCK_UNISWAP_ROUTER;
    address MOCK_FACTORY;

    MockTokenConfig[] private mockTokens;
    address receiver = 0x7C7bcF1d605F3fEe8E61bCa7605b3007C8b389be;

    constructor() {}

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "pharosTestnet";

        MOCK_UNISWAP_ROUTER = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_UNISWAP_ROUTER"));
        MOCK_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_FACTORY"));

        mockTokens.push(MockTokenConfig("Mock DAI", "laDAI", 18, 1e18, 1_000_000e18));
        mockTokens.push(MockTokenConfig("Mock USD Coin", "laUSDC", 6, 1e6, 1_000_000e6));
        mockTokens.push(MockTokenConfig("Mock USD Token", "laUSDT", 6, 1e6, 1_000_000e6));
        mockTokens.push(MockTokenConfig("Mock Wrapped Bitcoin", "laWBTC", 8, 100_000e8, 1_000e8));
        mockTokens.push(MockTokenConfig("Mock Wrapped Ethereum", "laWETH", 18, 2_500e18, 40_000e18));
    }

    function setupMockTokens() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        MockFactory mockFactory = MockFactory(MOCK_FACTORY);
        MockUniswapRouter mockUniswapRouter = MockUniswapRouter(MOCK_UNISWAP_ROUTER);

        console.log("Mock Uniswap Router deployed at:", MOCK_UNISWAP_ROUTER);
        console.log("Mock Factory deployed at:", MOCK_FACTORY);

        for (uint256 i = 0; i < mockTokens.length; i++) {
            MockTokenConfig memory token = mockTokens[i];

            address tokenAddr = mockFactory.createMockToken(token.name, token.symbol, token.decimals);
            address aggregatorAddr =
                mockFactory.createMockAggregator(token.name, token.symbol, token.decimals, token.price);

            mockUniswapRouter.setPriceFeed(tokenAddr, aggregatorAddr);

            console.log(string(abi.encodePacked("================", token.symbol, "=================")));
            console.log("Mock Token deployed at: ", tokenAddr);
            console.log("Mock Aggregator deployed at: ", aggregatorAddr);
            console.log("===========================================================");
        }
        vm.stopBroadcast();
    }

    function run() external {
        setupMockTokens();
    }
}
