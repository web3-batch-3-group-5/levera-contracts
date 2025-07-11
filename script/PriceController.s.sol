// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";

contract PriceController is Script {
    address MOCK_FACTORY;

    struct TokenPriceFeed {
        string name;
        string symbol;
        address priceFeed;
    }

    TokenPriceFeed[] public priceFeeds;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "eduChainTestnet";

        MOCK_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_FACTORY"));

        // Add your custom tokens here
        priceFeeds.push(TokenPriceFeed("Mock DAI", "laDAI", address(0)));
        priceFeeds.push(TokenPriceFeed("Mock USD Coin", "laUSDC", address(0)));
        priceFeeds.push(TokenPriceFeed("Mock USD Token", "laUSDT", address(0)));
        priceFeeds.push(TokenPriceFeed("Mock Wrapped Bitcoin", "laWBTC", address(0)));
        priceFeeds.push(TokenPriceFeed("Mock Wrapped Ethereum", "laWETH", address(0)));
    }

    function loadPriceFeeds() public {
        MockFactory factory = MockFactory(MOCK_FACTORY);

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            bytes32 id = keccak256(abi.encode(priceFeeds[i].name, priceFeeds[i].symbol));
            address aggregator = factory.aggregators(id);
            priceFeeds[i].priceFeed = aggregator;

            console.log("Loaded price feed for", priceFeeds[i].symbol, ":", aggregator);
        }
    }

    function updatePrice(string memory _symbol, int256 _newPrice) public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        address priceFeed = getPriceFeed(_symbol);
        require(priceFeed != address(0), "Price feed not found");

        MockPriceFeed(priceFeed).updatePrice(_newPrice);

        console.log("Updated price for token");
        console.log(_symbol);
        console.logInt(_newPrice);
        vm.stopBroadcast();
    }

    function setPriceByPercentage(string memory _symbol, int256 _percentageChange) public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        address priceFeed = getPriceFeed(_symbol);
        require(priceFeed != address(0), "Price feed not found");

        MockPriceFeed(priceFeed).setPriceByPercentage(_percentageChange);

        console.log("Updated price for token by percentage");
        console.log(_symbol);
        console.logInt(_percentageChange);
        vm.stopBroadcast();
    }

    function simulateVolatility(string memory _symbol, int256 _minPrice, int256 _maxPrice) public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        address priceFeed = getPriceFeed(_symbol);
        require(priceFeed != address(0), "Price feed not found");

        MockPriceFeed(priceFeed).simulateVolatility(_minPrice, _maxPrice);

        console.log("Simulated volatility for token");
        console.log(_symbol);
        vm.stopBroadcast();
    }

    function resetToBasePrice(string memory _symbol) public {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));

        address priceFeed = getPriceFeed(_symbol);
        require(priceFeed != address(0), "Price feed not found");

        MockPriceFeed(priceFeed).resetToBasePrice();

        console.log("Reset price for token to base price");
        console.log(_symbol);
        vm.stopBroadcast();
    }

    function getCurrentPrice(string memory _symbol) public view returns (int256) {
        address priceFeed = getPriceFeed(_symbol);
        require(priceFeed != address(0), "Price feed not found");

        return MockPriceFeed(priceFeed).getCurrentPrice();
    }

    function getPriceFeed(string memory _symbol) public view returns (address) {
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (keccak256(abi.encodePacked(priceFeeds[i].symbol)) == keccak256(abi.encodePacked(_symbol))) {
                return priceFeeds[i].priceFeed;
            }
        }
        return address(0);
    }

    function showAllPrices() public view {
        console.log("=== Current Token Prices ===");
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].priceFeed != address(0)) {
                int256 price = MockPriceFeed(priceFeeds[i].priceFeed).getCurrentPrice();
                console.log(priceFeeds[i].symbol);
                console.log("price:", uint256(price));
            }
        }
    }

    // Convenience functions for common operations
    function pumpPrice(string memory _symbol, int256 _percentage) public {
        require(_percentage > 0, "Percentage must be positive");
        setPriceByPercentage(_symbol, _percentage);
    }

    function dumpPrice(string memory _symbol, int256 _percentage) public {
        require(_percentage > 0 && _percentage < 100, "Percentage must be between 0 and 100");
        setPriceByPercentage(_symbol, -_percentage);
    }

    function crashPrice(string memory _symbol) public {
        setPriceByPercentage(_symbol, -50); // 50% crash
    }

    function moonPrice(string memory _symbol) public {
        setPriceByPercentage(_symbol, 100); // 100% pump
    }

    function run() external {
        loadPriceFeeds();
        showAllPrices();
    }
}
