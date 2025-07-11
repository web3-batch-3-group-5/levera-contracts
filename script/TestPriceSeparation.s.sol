// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MockMarginEngine} from "../src/mocks/MockMarginEngine.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";

contract TestPriceSeparation is Script {
    MockMarginEngine public marginEngine;
    MockFactory public factory;

    function setUp() public {
        // We'll deploy factory in each test to avoid config.json dependencies
        marginEngine = MockMarginEngine(payable(address(0))); // Will be set in deploy
    }

    function deployAndSetup() public returns (address) {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        // Deploy MockFactory first
        factory = new MockFactory();
        
        // Deploy MockMarginEngine
        marginEngine = new MockMarginEngine(address(factory), address(factory));

        // Create test token and price feed
        address token = factory.createMockToken("Test Token", "TEST", 18);
        address priceFeed = factory.createMockAggregator("Test Token", "TEST", 18, 1000e18);

        // Transfer price feed ownership from factory to margin engine
        factory.transferPriceFeedOwnership("Test Token", "TEST", address(marginEngine));

        // Add token to margin engine
        marginEngine.addMockToken("TEST", token, priceFeed, 18);

        console.log("MockFactory deployed at:", address(factory));
        console.log("MockMarginEngine deployed at:", address(marginEngine));
        console.log("Test token created at:", token);
        console.log("Test price feed created at:", priceFeed);

        vm.stopBroadcast();
        return address(marginEngine);
    }

    function testViewFunction() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing getOraclePriceView (View Function) ===");

        // Test view function - should work without state changes
        try marginEngine.getOraclePriceView("TEST") returns (uint256 price, uint256 updatedAt, bool isStale) {
            console.log("View function SUCCESS:");
            console.log("Price:", price);
            console.log("Updated at:", updatedAt);
            console.log("Is stale:", isStale);
        } catch Error(string memory reason) {
            console.log("View function FAILED:", reason);
        }

        vm.stopBroadcast();
    }

    function testNonViewFunction() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing getOraclePrice (Non-View Function) ===");

        // Test non-view function - can emit events
        try marginEngine.getOraclePrice("TEST") returns (uint256 price, uint256 updatedAt, bool isStale) {
            console.log("Non-view function SUCCESS:");
            console.log("Price:", price);
            console.log("Updated at:", updatedAt);
            console.log("Is stale:", isStale);
        } catch Error(string memory reason) {
            console.log("Non-view function FAILED:", reason);
        }

        vm.stopBroadcast();
    }

    function testSetPriceFunction() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing setPrice Functionality ===");

        // Get original price
        (uint256 originalPrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Original price:", originalPrice);

        // Set manual price
        uint256 newPrice = 1500e18;
        marginEngine.setPrice("TEST", newPrice);
        console.log("Set manual price to:", newPrice);

        // Get updated price
        (uint256 updatedPrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Updated price:", updatedPrice);

        require(updatedPrice == newPrice, "Price not updated correctly");
        console.log("SUCCESS: Manual price setting");

        vm.stopBroadcast();
    }

    function testStalePrice() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing Stale Price Handling ===");

        // Set a very short stale threshold for testing
        marginEngine.setStalePriceThreshold(1); // 1 second

        // Wait to make price stale (simulate with manual price)
        marginEngine.setPrice("TEST", 1000e18);

        // Check if price is considered stale
        (,, bool isStale) = marginEngine.getOraclePriceView("TEST");
        console.log("Is price stale:", isStale);

        // Use autoSetPriceOnStale if stale
        if (isStale) {
            try marginEngine.autoSetPriceOnStale("TEST") {
                console.log("SUCCESS: Auto-set price on stale");
            } catch Error(string memory reason) {
                console.log("Auto-set price FAILED:", reason);
            }
        } else {
            console.log("Price is not stale, skipping auto-set");
        }

        vm.stopBroadcast();
    }

    function testDisableManualPrice() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing Disable Manual Price ===");

        // Set manual price first
        marginEngine.setPrice("TEST", 2000e18);
        console.log("Set manual price to 2000");

        // Check it's being used
        (uint256 manualPrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Current price (manual):", manualPrice);

        // Disable manual price
        marginEngine.disableManualPrice("TEST");
        console.log("Disabled manual price");

        // Check it's back to oracle
        (uint256 oraclePrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Current price (oracle):", oraclePrice);

        console.log("SUCCESS: Disable manual price");

        vm.stopBroadcast();
    }

    function testMockPriceManipulation() public {
        deployAndSetup(); // Deploy contracts first
        
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        console.log("=== Testing Mock Price Manipulation ===");

        // Get original price
        (uint256 originalPrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Original price:", originalPrice);

        // Update mock price by percentage using MockMarginEngine function (which owns the price feed)
        marginEngine.updateMockPriceByPercentage("TEST", 50); // 50% increase

        // Get updated price
        (uint256 updatedPrice,,) = marginEngine.getOraclePriceView("TEST");
        console.log("Updated price (+50%):", updatedPrice);

        // Verify the increase (with some tolerance for conversion calculations)
        uint256 expectedPrice = originalPrice + (originalPrice * 50 / 100);
        require(updatedPrice >= expectedPrice * 99 / 100, "Price increase too small");
        require(updatedPrice <= expectedPrice * 101 / 100, "Price increase too large");

        console.log("SUCCESS: Mock price manipulation");

        vm.stopBroadcast();
    }

    function runAllTests() external {
        address engineAddr = deployAndSetup();

        console.log("Running all price separation tests...");

        testViewFunction();
        testNonViewFunction();
        testSetPriceFunction();
        testStalePrice();
        testDisableManualPrice();
        testMockPriceManipulation();

        console.log("=== All Tests Completed ===");
        console.log("MarginEngine with price separation deployed at:", engineAddr);
    }
}
