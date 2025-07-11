// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";

contract MockPriceFeed is MockV3Aggregator {
    address public owner;
    int256 public basePrice;
    int256 public currentPrice;

    event PriceUpdated(int256 oldPrice, int256 newPrice, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(uint8 _decimals, int256 _initialPrice) MockV3Aggregator(_decimals, _initialPrice) {
        owner = msg.sender;
        basePrice = _initialPrice;
        currentPrice = _initialPrice;
    }

    function updatePrice(int256 _newPrice) external onlyOwner {
        int256 oldPrice = currentPrice;
        currentPrice = _newPrice;
        updateAnswer(_newPrice);
        emit PriceUpdated(oldPrice, _newPrice, block.timestamp);
    }

    function setPriceByPercentage(int256 _percentageChange) external onlyOwner {
        require(_percentageChange > -100, "Cannot decrease price by more than 100%");

        int256 oldPrice = currentPrice;
        int256 newPrice = (currentPrice * (100 + _percentageChange)) / 100;

        currentPrice = newPrice;
        updateAnswer(newPrice);
        emit PriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    function resetToBasePrice() external onlyOwner {
        int256 oldPrice = currentPrice;
        currentPrice = basePrice;
        updateAnswer(basePrice);
        emit PriceUpdated(oldPrice, basePrice, block.timestamp);
    }

    function simulateVolatility(int256 _minPrice, int256 _maxPrice) external onlyOwner {
        require(_minPrice < _maxPrice, "Invalid price range");
        require(_minPrice > 0, "Min price must be positive");

        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        int256 priceRange = _maxPrice - _minPrice;
        int256 randomPrice = _minPrice + int256(randomSeed % uint256(priceRange));

        int256 oldPrice = currentPrice;
        currentPrice = randomPrice;
        updateAnswer(randomPrice);
        emit PriceUpdated(oldPrice, randomPrice, block.timestamp);
    }

    function getCurrentPrice() external view returns (int256) {
        return currentPrice;
    }

    function getBasePrice() external view returns (int256) {
        return basePrice;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
