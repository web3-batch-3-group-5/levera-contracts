// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "../MarginEngine.sol";
import "./MockPriceFeed.sol";

contract MockMarginEngine is MarginEngine {
    mapping(string => address) public mockPriceFeeds;
    bool public useMockPrices = true;
    
    event MockPriceUpdated(string indexed symbol, int256 newPrice);
    
    constructor(address _quoter, address _swapRouter) MarginEngine(_quoter, _swapRouter) {
        // Set longer stale threshold for testing
        stalePriceThreshold = 86400; // 24 hours
    }

    /// @notice Add token with mock price feed for testing
    function addMockToken(
        string memory symbol,
        address token,
        address mockPriceFeed,
        uint8 decimals
    ) external onlyOwner {
        // Add to main contract
        super.addToken(symbol, token, mockPriceFeed, decimals);
        
        // Store reference to mock price feed
        mockPriceFeeds[symbol] = mockPriceFeed;
    }

    /// @notice Toggle between mock and real prices
    function setUseMockPrices(bool _useMock) external onlyOwner {
        useMockPrices = _useMock;
    }

    /// @notice Update mock price for testing
    function updateMockPrice(string memory symbol, int256 newPrice) public onlyOwner {
        address mockFeed = mockPriceFeeds[symbol];
        require(mockFeed != address(0), "Mock feed not found");
        
        MockPriceFeed(mockFeed).updatePrice(newPrice);
        emit MockPriceUpdated(symbol, newPrice);
    }

    /// @notice Update mock price by percentage
    function updateMockPriceByPercentage(string memory symbol, int256 percentageChange) public onlyOwner {
        address mockFeed = mockPriceFeeds[symbol];
        require(mockFeed != address(0), "Mock feed not found");
        
        MockPriceFeed(mockFeed).setPriceByPercentage(percentageChange);
        
        int256 currentPrice = MockPriceFeed(mockFeed).getCurrentPrice();
        emit MockPriceUpdated(symbol, currentPrice);
    }

    /// @notice Simulate price volatility for testing
    function simulateMockVolatility(string memory symbol, int256 minPrice, int256 maxPrice) external onlyOwner {
        address mockFeed = mockPriceFeeds[symbol];
        require(mockFeed != address(0), "Mock feed not found");
        
        MockPriceFeed(mockFeed).simulateVolatility(minPrice, maxPrice);
        
        int256 currentPrice = MockPriceFeed(mockFeed).getCurrentPrice();
        emit MockPriceUpdated(symbol, currentPrice);
    }

    /// @notice Reset mock price to base for testing
    function resetMockPrice(string memory symbol) external onlyOwner {
        address mockFeed = mockPriceFeeds[symbol];
        require(mockFeed != address(0), "Mock feed not found");
        
        MockPriceFeed(mockFeed).resetToBasePrice();
        
        int256 currentPrice = MockPriceFeed(mockFeed).getCurrentPrice();
        emit MockPriceUpdated(symbol, currentPrice);
    }

    /// @notice Get mock price feed address
    function getMockPriceFeed(string memory symbol) external view returns (address) {
        return mockPriceFeeds[symbol];
    }

    /// @notice Override oracle price view to use mock when enabled
    function getOraclePriceView(string memory symbol) public view override returns (uint256 price, uint256 updatedAt, bool isStale) {
        if (useMockPrices && mockPriceFeeds[symbol] != address(0)) {
            // Use mock price feed
            MockPriceFeed mockFeed = MockPriceFeed(mockPriceFeeds[symbol]);
            
            (, int256 rawPrice, , uint256 timeStamp, ) = mockFeed.latestRoundData();
            require(rawPrice > 0, "Invalid mock price");
            
            // Mock feeds are never stale in testing
            isStale = false;
            price = uint256(rawPrice) * 1e18 / (10 ** mockFeed.decimals());
            updatedAt = timeStamp;
        } else {
            // Use real oracle
            return super.getOraclePriceView(symbol);
        }
    }

    /// @notice Batch update multiple mock prices
    function batchUpdateMockPrices(
        string[] memory symbols,
        int256[] memory newPrices
    ) external onlyOwner {
        require(symbols.length == newPrices.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < symbols.length; i++) {
            updateMockPrice(symbols[i], newPrices[i]);
        }
    }

    /// @notice Simulate market crash for testing
    function simulateMarketCrash(string[] memory symbols, int256 crashPercentage) external onlyOwner {
        require(crashPercentage < 0 && crashPercentage > -100, "Invalid crash percentage");
        
        for (uint256 i = 0; i < symbols.length; i++) {
            updateMockPriceByPercentage(symbols[i], crashPercentage);
        }
    }

    /// @notice Simulate market pump for testing
    function simulateMarketPump(string[] memory symbols, int256 pumpPercentage) external onlyOwner {
        require(pumpPercentage > 0, "Pump percentage must be positive");
        
        for (uint256 i = 0; i < symbols.length; i++) {
            updateMockPriceByPercentage(symbols[i], pumpPercentage);
        }
    }

    /// @notice Get all mock prices for display
    function getAllMockPrices(string[] memory symbols) external view returns (
        uint256[] memory prices,
        uint256[] memory timestamps
    ) {
        prices = new uint256[](symbols.length);
        timestamps = new uint256[](symbols.length);
        
        for (uint256 i = 0; i < symbols.length; i++) {
            if (mockPriceFeeds[symbols[i]] != address(0)) {
                MockPriceFeed mockFeed = MockPriceFeed(mockPriceFeeds[symbols[i]]);
                prices[i] = uint256(mockFeed.getCurrentPrice());
                timestamps[i] = block.timestamp;
            }
        }
    }
}