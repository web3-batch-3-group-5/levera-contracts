// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PriceConverterLib} from "./libraries/PriceConverterLib.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {PositionParams, IPosition} from "./interfaces/IPosition.sol";
import {PositionType} from "./interfaces/ILendingPool.sol";

interface IFlashLoanCallback {
    function onFlashLoan(address token, uint256 amount, bytes calldata data) external;
}

contract LendingPool {
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InvalidAmount();
    error NoActivePosition();
    error NonZeroActivePosition();
    error ZeroAddress();
    error ZeroAmount();
    error FlashLoanFailed();

    address public immutable owner;
    address public immutable creator;
    bytes32 public immutable contractId;
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;
    AggregatorV2V3Interface public loanTokenUsdDataFeed;
    AggregatorV2V3Interface public collateralTokenUsdDataFeed;
    PositionType public positionType;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 public totalCollateral;
    uint256 public ltv = 70;
    uint8 public liquidationThresholdPercentage;
    uint8 public interestRate;
    uint256 lastAccrued = block.timestamp;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => mapping(address => PositionParams)) public userPositions;

    constructor(
        IERC20 _loanToken,
        IERC20 _collateralToken,
        AggregatorV2V3Interface _loanTokenUsdPriceFeed,
        AggregatorV2V3Interface _collateralTokenUsdPriceFeed,
        uint8 _liquidationThresholdPercentage,
        uint8 _interestRate,
        PositionType _positionType,
        address _creator
    ) {
        owner = msg.sender;
        creator = _creator;
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        loanTokenUsdDataFeed = _loanTokenUsdPriceFeed;
        collateralTokenUsdDataFeed = _collateralTokenUsdPriceFeed;
        liquidationThresholdPercentage = _liquidationThresholdPercentage;
        positionType = _positionType;
        interestRate = _interestRate;
        contractId = _getContractId();
    }

    modifier onlyActivePosition(address onBehalf) {
        if (!userPositions[msg.sender][onBehalf]) revert NoActivePosition();
        _;
    }

    function _getContractId() public view returns (bytes32) {
        return keccak256(abi.encode(address(loanToken), address(collateralToken)));
    }

    function supply(uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        if (msg.sender == address(0) || address(loanToken) == address(0)) revert ZeroAddress();

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

        // Transfer USDC from sender to contract
        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);

        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Supply(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function withdraw(uint256 shares) public {
        if (shares == 0) revert ZeroAmount();
        if (shares > userSupplyShares[msg.sender]) revert InsufficientShares();

        _accrueInterest();

        uint256 amount = (shares * totalSupplyAssets) / totalSupplyShares;
        if (amount > totalSupplyAssets) revert InsufficientLiquidity();

        totalSupplyAssets -= amount;
        totalSupplyShares -= shares;
        userSupplyShares[msg.sender] -= shares;

        IERC20(loanToken).transfer(msg.sender, amount);

        emit EventLib.UserSupplyShare(address(this), msg.sender, userSupplyShares[msg.sender]);
        emit EventLib.Withdraw(address(this), msg.sender, userSupplyShares[msg.sender]);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        /*
        inside Position.sol
        
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        baseCollateral += amount;

        lendingPool.supplyCollateralByPosition(address(this), amount);

        _updatePosition(onBehalf);
        emit EventLib.SupplyCollateralByPosition(
            address(lendingPool), msg.sender, address(this), currPositionParams())
        );

         */

        totalCollateral += amount;
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawCollateralByPosition(address onBehalf, uint256 amount) public onlyActivePosition(onBehalf) {
        /*
        inside Position.sol
        
        if (amount == 0) revert ZeroAmount();
        if (amount > collateral) revert InsufficientCollateral();
        baseCollateral -= amount;

        _isHealthy(address(this));
        lendingPool.withdrawCollateralByPosition(address(this), amount);

        _updatePosition(onBehalf);
        emit EventLib.WithdrawCollateralByPosition(
            address(lendingPool), msg.sender, address(this), currPositionParams())
        );

        IERC20(collateralToken).transfer(msg.sender, amount);

         */

        totalCollateral -= amount;
        IERC20(collateralToken).transfer(msg.sender, amount);
    }

    function borrowByPosition(address onBehalf, uint256 amount)
        public
        onlyActivePosition(onBehalf)
        returns (uint256 shares)
    {
        uint256 availableLiquidity = IERC20(loanToken).balanceOf(address(this));
        if (availableLiquidity < amount) revert InsufficientLiquidity();

        _accrueInterest();

        // uint256 shares = 0;
        if (totalBorrowAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAssets;
        }

        totalBorrowAssets += amount;
        totalBorrowShares += shares;

        return shares;
        /*
        inside Position.sol

        uint256 shares = borrowByPosition(...)
        borrowShares += shares;
        _isHealthy();

        _updatePosition(onBehalf);
        emit EventLib.BorrowByPosition(address(lendingPool), msg.sender, address(this), currPositionParams())
         */
    }

    function repayByPosition(address onBehalf, uint256 amount)
        public
        onlyActivePosition(onBehalf)
        returns (uint256 shares)
    {
        _accrueInterest();

        if (totalBorrowShares == 0) revert InvalidAmount();

        // uint256 shares = 0;
        if (totalBorrowAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalBorrowShares) / totalBorrowAssets;
        }

        totalBorrowShares -= shares;
        totalBorrowAssets -= amount;

        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);
        return shares;

        /*
        inside Position.sol

        if (amount == 0 || borrowShares == 0) revert InvalidAmount();

        IERC20(loanToken).transferFrom(msg.sender, address(this), amount);

        uint256 shares = repayByPosition(...)
        borrowShares -= shares;
        
        _updatePosition(onBehalf);
        emit EventLib.RepayByPosition(address(lendingPool), msg.sender, address(this), currPositionParams());

         */
    }

    function accrueInterest() public {
        _accrueInterest();
    }

    function _accrueInterest() internal {
        uint256 interestPerYear = totalBorrowAssets * interestRate / 100;
        uint256 elapsedTime = block.timestamp - lastAccrued;

        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        totalBorrowAssets += interest;
        totalSupplyAssets += interest;

        lastAccrued = block.timestamp;

        emit EventLib.AccrueInterest(address(this), interestRate, interest);
    }

    // flashloan
    function flashLoan(address token, uint256 amount, bytes calldata data) external {
        if (amount == 0) revert ZeroAmount();

        IERC20(token).transfer(msg.sender, amount);

        IFlashLoanCallback(msg.sender).onFlashLoan(token, amount, data);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function getLiquidationPrice(uint256 effectiveCollateral, uint256 borrowAmount) external view returns (uint256) {
        uint8 liquidationThreshold = liquidationThresholdPercentage / 100;
        return uint256(borrowAmount / (effectiveCollateral * liquidationThreshold));
    }

    function getHealth(uint256 effectiveCollateralPrice, uint256 borrowAmount) external view returns (uint8) {
        uint8 liquidationThreshold = liquidationThresholdPercentage / 100;
        return uint8((effectiveCollateralPrice * liquidationThreshold) / borrowAmount);
    }

    function getLTV(uint256 effectiveCollateralPrice, uint256 borrowShares) external view returns (uint8) {
        return uint8(borrowShares / effectiveCollateralPrice);
    }
}
