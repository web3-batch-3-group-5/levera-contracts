// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

contract LendingPool {
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface internal loanTokenUsdDataFeed;
    AggregatorV2V3Interface internal collateralTokenUsdDataFeed;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 lastAccrued;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => uint256) public userBorrowShares;
    mapping(address => uint256) public userCollaterals;

    uint256 constant PRECISION = 1e18; // Precision

    constructor(IERC20 _loanToken, IERC20 _collateralToken) {
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        lastAccrued = block.timestamp;
    }

    function getDataFeedLatestAnswer(AggregatorV2V3Interface dataFeed) public view returns (uint256) {
        (, int256 answer,,,) = dataFeed.latestRoundData();
        require(answer >= 0, ErrorsLib.NegativeAnswer)
        return uint256(answer) * PRECISION / (10 ** dataFeed.decimals());
    }

    function getConversionPrice(
        uint256 amountIn,
        AggregatorV2V3Interface dataFeedIn,
        AggregatorV2V3Interface dataFeedOut
    ) public view returns (uint256 amountOut) {
        uint256 priceFeedIn = getDataFeedLatestAnswer(dataFeedIn);
        uint256 priceFeedOut = getDataFeedLatestAnswer(dataFeedOut);

        amountOut = (amountIn * priceFeedIn) / priceFeedOut;
    }

    function supply(uint256 amount) public {
        require(msg.sender != address(0), ErrorsLib.ZERO_ADDRESS);
        require(address(loanToken) != address(0), ErrorsLib.ZERO_ADDRESS);

        // Transfer USDC from sender to contract
        bool success = IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        require(success, ErrorsLib.TRANSFER_REVERTED);

        _accrueInterest();

        uint256 shares = 0;
        if (totalSupplyAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupplyShares) / totalSupplyAssets;
        }

        totalSupplyAssets += amount;
        totalSupplyShares += shares;
        userSupplyShares[msg.sender] += shares;
    }

    function withdraw(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;
        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function supplyCollateral(uint256 amount) public {
        _accrueInterest();

        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        userCollaterals[msg.sender] += amount;
    }

    function withdrawCollateral(uint256 amount) public {
        _accrueInterest();

        IERC20(collateralToken).transfer(msg.sender, amount);
        userCollaterals[msg.sender] -= amount;
    }

    function borrow(uint256 amount) public {
        _accrueInterest();

        uint256 shares = 0;
        if (totalBorrowAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAssets;
        }

        totalBorrowAssets += amount;
        totalBorrowShares += shares;
        userBorrowShares[msg.sender] += shares;

        IERC20(loanToken).transfer(msg.sender, amount);
    }

    function repay(uint256 shares) public {
        _accrueInterest();

        uint256 amount = (shares * totalBorrowAssets) / totalBorrowShares;

        totalBorrowAssets -= amount;
        totalBorrowShares -= shares;
        userBorrowShares[msg.sender] -= shares;

        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    function _accrueInterest() internal {
        uint256 borrowRate = 5;

        uint256 interestPerYear = totalBorrowAssets * borrowRate / 100;
        uint256 elapsedTime = block.timestamp - lastAccrued;

        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        totalBorrowAssets += interest;
        totalSupplyAssets += interest;

        lastAccrued = block.timestamp;
    }
}
