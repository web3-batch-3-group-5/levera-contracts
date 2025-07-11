// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MockMarginEngine} from "../src/mocks/MockMarginEngine.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";

contract MarginEngineSetup is Script {
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
    }

    address MOCK_UNISWAP_ROUTER;
    address MOCK_FACTORY;
    address MOCK_QUOTER;

    MockMarginEngine public marginEngine;
    TokenConfig[] private tokenConfigs;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "eduChainTestnet";

        MOCK_UNISWAP_ROUTER = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_UNISWAP_ROUTER"));
        MOCK_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_FACTORY"));

        // For testing, use the same address as router for quoter
        MOCK_QUOTER = MOCK_UNISWAP_ROUTER;

        // Configure test tokens
        tokenConfigs.push(TokenConfig("Mock DAI", "laDAI", 18, 1e18));
        tokenConfigs.push(TokenConfig("Mock USD Coin", "laUSDC", 6, 1e6));
        tokenConfigs.push(TokenConfig("Mock USD Token", "laUSDT", 6, 1e6));
        tokenConfigs.push(TokenConfig("Mock Wrapped Bitcoin", "laWBTC", 8, 100_000e8));
        tokenConfigs.push(TokenConfig("Mock Wrapped Ethereum", "laWETH", 18, 2_500e18));
    }

    function deployMarginEngine() public returns (address) {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        // Deploy MockMarginEngine
        marginEngine = new MockMarginEngine(MOCK_QUOTER, MOCK_UNISWAP_ROUTER);

        console.log("MockMarginEngine deployed at:", address(marginEngine));

        vm.stopBroadcast();
        return address(marginEngine);
    }

    function setupTokens() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        MockFactory factory = MockFactory(MOCK_FACTORY);

        console.log("Setting up tokens in MarginEngine...");

        for (uint256 i = 0; i < tokenConfigs.length; i++) {
            TokenConfig memory config = tokenConfigs[i];

            // Get token and price feed from factory
            bytes32 id = keccak256(abi.encode(config.name, config.symbol));
            address token = factory.tokens(id);
            address priceFeed = factory.aggregators(id);

            if (token != address(0) && priceFeed != address(0)) {
                // Add token to margin engine
                marginEngine.addMockToken(config.symbol, token, priceFeed, config.decimals);

                console.log("Added token:", config.symbol);
                console.log("Token address:", token);
                console.log("Price feed:", priceFeed);
                console.log("---");
            } else {
                console.log("Token not found in factory:", config.symbol);
            }
        }

        vm.stopBroadcast();
    }

    function demonstratePricing() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Demonstrating Dual Pricing System ===");

        // Test oracle price (for frontend display)
        try marginEngine.getOraclePrice("laUSDC") returns (uint256 price, uint256 timestamp, bool isStale) {
            console.log("Oracle Price for laUSDC:", price);
            console.log("Timestamp:", timestamp);
            console.log("Is stale:", isStale);
        } catch {
            console.log("Oracle price fetch failed for laUSDC");
        }

        // Test Uniswap price (for actual swaps)
        try marginEngine.getUniswapPrice("laUSDC", "laDAI", 1000000, 500) returns (uint256 amountOut) {
            console.log("Uniswap price for 1 USDC -> DAI:", amountOut);
        } catch {
            console.log("Uniswap price fetch failed");
        }

        vm.stopBroadcast();
    }

    function demonstratePriceManipulation() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Demonstrating Price Manipulation ===");

        // Pump USDC price by 10%
        marginEngine.updateMockPriceByPercentage("laUSDC", 10);
        console.log("Pumped laUSDC by 10%");

        // Dump WBTC price by 20%
        marginEngine.updateMockPriceByPercentage("laWBTC", -20);
        console.log("Dumped laWBTC by 20%");

        // Simulate volatility for ETH
        marginEngine.simulateMockVolatility("laWETH", 2000e18, 3000e18);
        console.log("Simulated volatility for laWETH");

        vm.stopBroadcast();
    }

    function demonstratePositionCalculation() public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Demonstrating Position Calculation ===");

        // Calculate position requirements
        try marginEngine.calculatePositionRequirements("laWETH", "laUSDC", 1e18, 300) returns (
            uint256 borrowAmount, uint256 liquidationPrice, uint256 healthFactor
        ) {
            console.log("Position with 1 ETH at 3x leverage:");
            console.log("Borrow amount (USDC):", borrowAmount);
            console.log("Liquidation price:", liquidationPrice);
            console.log("Health factor:", healthFactor);
        } catch {
            console.log("Position calculation failed");
        }

        vm.stopBroadcast();
    }

    function showAllPrices() public view {
        console.log("=== Current Token Prices ===");

        string[] memory symbols = new string[](tokenConfigs.length);
        for (uint256 i = 0; i < tokenConfigs.length; i++) {
            symbols[i] = tokenConfigs[i].symbol;
        }

        try marginEngine.getAllMockPrices(symbols) returns (uint256[] memory prices, uint256[] memory timestamps) {
            for (uint256 i = 0; i < symbols.length; i++) {
                console.log(symbols[i]);
                console.log("Price:", prices[i]);
                console.log("Timestamp:", timestamps[i]);
                console.log("---");
            }
        } catch {
            console.log("Failed to fetch all prices");
        }
    }

    function run() external {
        address marginEngineAddr = deployMarginEngine();
        setupTokens();

        console.log("=== MarginEngine Setup Complete ===");
        console.log("MarginEngine address:", marginEngineAddr);
        console.log("You can now use both pricing mechanisms:");
        console.log("- Oracle prices for frontend display");
        console.log("- Uniswap prices for actual swaps");
    }

    // Convenience functions for testing
    function pumpToken(string memory symbol, int256 percentage) external {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        marginEngine.updateMockPriceByPercentage(symbol, percentage);
        console.log("Pumped token by percentage");
        console.log(symbol);
        console.logInt(percentage);

        vm.stopBroadcast();
    }

    function dumpToken(string memory symbol, int256 percentage) external {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        marginEngine.updateMockPriceByPercentage(symbol, -percentage);
        console.log("Dumped token by percentage");
        console.log(symbol);
        console.logInt(percentage);

        vm.stopBroadcast();
    }

    function simulateMarketCrash(int256 percentage) external {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        string[] memory symbols = new string[](tokenConfigs.length);
        for (uint256 i = 0; i < tokenConfigs.length; i++) {
            symbols[i] = tokenConfigs[i].symbol;
        }

        marginEngine.simulateMarketCrash(symbols, -percentage);
        console.log("Simulated market crash of percentage");
        console.logInt(percentage);

        vm.stopBroadcast();
    }
}
