// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {PriceConverterLib} from "../src/libraries/PriceConverterLib.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";

contract IntegrationTest is Test {
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    LendingPool public lendingPool;
    LendingPoolFactory public lendingPoolFactory;
    PositionFactory public positionFactory;
    MockFactory public mockFactory;

    uint8 liquidationThresholdPercentage = 80;
    uint8 interestRate = 5;
    PositionType positionType = PositionType.LONG;
    mapping(address => mapping(address => bool)) public positions;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Setup Factory
        MockUniswapRouter mockUniswapRouter = new MockUniswapRouter();
        lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter));
        positionFactory = new PositionFactory();
        mockFactory = new MockFactory();

        // Setup WBTC - USDC lending pool
        address loanToken = mockFactory.createMockToken("usdc", "USDC");
        address loanTokenAggregator = mockFactory.createMockAggregator("usdc", "USDC", 6, 1e6);
        address collateralToken = mockFactory.createMockToken("wbtc", "WBTC");
        address collateralTokenAggregator = mockFactory.createMockAggregator("wbtc", "WBTC", 8, 100_000e8);
        mockUSDC = MockERC20(loanToken);
        mockWBTC = MockERC20(collateralToken);
        usdcUsdPriceFeed = MockV3Aggregator(loanTokenAggregator);
        wbtcUsdPriceFeed = MockV3Aggregator(collateralTokenAggregator);
        address lendingPoolAddress = lendingPoolFactory.createLendingPool(
            address(mockUSDC),
            address(mockWBTC),
            address(usdcUsdPriceFeed),
            address(wbtcUsdPriceFeed),
            liquidationThresholdPercentage,
            interestRate,
            positionType
        );
        lendingPool = LendingPool(lendingPoolAddress);

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log("==============================================================");

        mockUSDC.mint(address(this), 1_000_000e6);
        supplyLiquidity(500_000e6);

        mockUSDC.mint(alice, 200_000e6);
        mockWBTC.mint(alice, 3e8);
        // Alice supply liquidity
        vm.startPrank(alice);
        supplyLiquidity(50_000e6);
        vm.stopPrank();

        mockUSDC.mint(bob, 200_000e6);
        mockWBTC.mint(bob, 2e8);
        // Bob supply liquidity
        vm.startPrank(bob);
        supplyLiquidity(50_000e6);
        vm.stopPrank();
    }

    function supplyLiquidity(uint256 amount) internal {
        IERC20(mockUSDC).approve(address(lendingPool), amount);
        lendingPool.supply(amount);
    }

    function createPosition(address user, uint256 _baseCollateral, uint8 _leverage)
        private
        returns (address onBehalf)
    {
        uint256 effectiveCollateral = _baseCollateral * _leverage / 100;

        vm.startPrank(user);
        IERC20(mockWBTC).approve(address(this), _baseCollateral);
        IERC20(mockWBTC).transfer(address(this), _baseCollateral);
        vm.stopPrank();

        // Treat IntegrationTest as PositionFactory
        Position position = new Position(address(lendingPool), lendingPool.router(), user);
        address positionAddr = address(position);
        positions[alice][positionAddr] = true;
        lendingPool.registerPosition(positionAddr);
        console.log("Position created at", address(positionAddr));

        IERC20(mockWBTC).approve(positionAddr, _baseCollateral);

        uint256 borrowAmount = position.convertCollateralPrice(_baseCollateral * (_leverage - 100) / 100);
        position.setRiskInfo(effectiveCollateral, borrowAmount);

        // Replace openPosition
        position.addCollateral(_baseCollateral);
        uint256 borrowCollateral = test_flashLoan(borrowAmount);
        position.borrow(borrowAmount);

        IERC20(mockWBTC).approve(positionAddr, borrowCollateral);
        position.addCollateral(borrowCollateral);

        console.log("Estimated Borrow Collateral Price", position.convertBorrowSharesToAmount(position.borrowShares()));

        return positionAddr;
    }

    function test_createPosition() public {
        uint256 baseCollateral = 1e8;
        uint8 leverage = 200;

        console.log("Before Alice create position");
        console.log("totalCollateral =", lendingPool.totalCollateral());
        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets =", lendingPool.totalBorrowAssets());
        console.log("==============================================================");

        // Alice Create Position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        assertTrue(positions[alice][onBehalf], "Position is registered in Position Factory");
        assertEq(
            IPosition(onBehalf).effectiveCollateral(),
            baseCollateral * leverage / 100,
            "Effective Collateral should be equal to Base Collateral multiplied by Leverage"
        );

        console.log("==============================================================");
        console.log("After Alice create position");
        console.log("totalCollateral =", lendingPool.totalCollateral());
        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets =", lendingPool.totalBorrowAssets());
    }

    function test_supplyCollateralByPosition_NoActivePosition() public {
        uint256 supplyCollateralAmount = 100_000e6;
        address randomOnBehalf = address(0x1234567890123456789012345678901234567890);

        vm.expectRevert(LendingPool.NoActivePosition.selector);
        lendingPool.supplyCollateralByPosition(randomOnBehalf, supplyCollateralAmount);
    }

    function test_addCollateral() public {
        uint256 baseCollateral = 1e8;
        uint8 leverage = 200;
        uint256 addedCollateral = 5e7;

        // Alice Create Position
        address onBehalf = createPosition(alice, baseCollateral, leverage);

        assertTrue(positions[alice][onBehalf], "Position is registered in Position Factory");
        console.log("==============================================================");
        console.log("After Alice create position");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());

        vm.startPrank(alice);
        IERC20(mockWBTC).approve(address(this), addedCollateral);
        IERC20(mockWBTC).transfer(address(this), addedCollateral);
        vm.stopPrank();

        IERC20(mockWBTC).approve(onBehalf, addedCollateral);
        IPosition(onBehalf).addCollateral(addedCollateral);

        console.log("==============================================================");
        console.log("After Alice add collateral");
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
    }

    // function test_borrowByPosition() public {
    //     uint256 supplyCollateralAmount = 1e6; // in wbtc
    //     uint256 borrowAmount = 10e6; // in usdc

    //     // Bob supply to lending pool
    //     uint256 bobDeposit = 1000e6;
    //     vm.startPrank(bob);
    //     IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

    //     lendingPool.supply(bobDeposit);
    //     vm.stopPrank();

    //     // Alice create position
    //     vm.startPrank(alice);
    //     address onBehalf = address(lendingPool.createPosition());
    //     IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

    //     // Check Alice balance Before
    //     uint256 aliceBalanceBefore = IERC20(mockUSDC).balanceOf(alice);
    //     assertEq(aliceBalanceBefore, 100_000e6, "Alice Balance Initial");

    //     // Alice supply collateral
    //     lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

    //     // Get initial position data
    //     (uint256 initialCollateral, uint256 initialBorrowed,,) = lendingPool.getPosition(onBehalf);

    //     // Ensure collateral was supplied correctly
    //     assertEq(initialCollateral, supplyCollateralAmount, "Collateral amount should be updated");
    //     assertEq(initialBorrowed, 0, "Initial borrowed amount should be zero");

    //     // Alice attempts to borrow
    //     lendingPool.borrowByPosition(onBehalf, borrowAmount);

    //     // Get updated position data
    //     (uint256 finalCollateral, uint256 finalBorrowed,,) = lendingPool.getPosition(onBehalf);

    //     // Verify borrow updates
    //     assertEq(finalCollateral, supplyCollateralAmount, "Collateral should remain the same");
    //     assertEq(finalBorrowed, borrowAmount, "Borrowed amount should be updated");

    //     // Check token balance
    //     uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
    //     assertEq(aliceBalanceAfter, aliceBalanceBefore += borrowAmount, "Alice should receive the borrowed tokens");

    //     console.log("Alice successfully borrowed", aliceBalanceBefore += borrowAmount);
    // }

    // function test_borrowByCollateral_InsufficientCollateral() public {
    //     uint256 supplyCollateralAmount = 1e4;
    //     uint256 borrowAmount = 2000e6; // More than allowed

    //     // Bob supply to lending pool
    //     uint256 bobDeposit = 3000e6;
    //     vm.startPrank(bob);
    //     IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

    //     lendingPool.supply(bobDeposit);
    //     vm.stopPrank();

    //     // Alice create position
    //     vm.startPrank(alice);
    //     address onBehalf = address(lendingPool.createPosition());
    //     IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

    //     // Alice supply collateral
    //     lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

    //     // Expect revert due to insufficient collateral
    //     vm.expectRevert(LendingPool.InsufficientCollateral.selector);
    //     lendingPool.borrowByPosition(onBehalf, borrowAmount);
    // }

    // function test_borrowByCollateral_InsufficientLiquidity() public {
    //     uint256 supplyCollateralAmount = 1e6;
    //     uint256 borrowAmount = 100e6;

    //     // Bob supply to lending pool
    //     uint256 bobDeposit = 30e6; // less than borrowed amount
    //     vm.startPrank(bob);
    //     IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

    //     lendingPool.supply(bobDeposit);
    //     vm.stopPrank();

    //     // Alice create position
    //     vm.startPrank(alice);
    //     address onBehalf = address(lendingPool.createPosition());
    //     IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

    //     // Alice supply collateral
    //     lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

    //     // Expect revert due to insufficient liquidity
    //     vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
    //     lendingPool.borrowByPosition(onBehalf, borrowAmount);
    // }

    // function test_repayByPosition() public {
    //     uint256 supplyCollateralAmount = 1e6;
    //     uint256 borrowAmount = 5e5;
    //     uint256 repayShares = 2e5;

    //     // Bob supply to lending pool
    //     uint256 bobDeposit = 30e6; // less than borrowed amount
    //     vm.startPrank(bob);
    //     IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

    //     lendingPool.supply(bobDeposit);
    //     vm.stopPrank();

    //     // Alice create position
    //     vm.startPrank(alice);
    //     address onBehalf = address(lendingPool.createPosition());
    //     IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

    //     // Alice supplies collateral
    //     lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

    //     // Alice borrows funds
    //     lendingPool.borrowByPosition(onBehalf, borrowAmount);

    //     // Get borrowed amount before repayment
    //     (, uint256 borrowedBefore,,) = lendingPool.getPosition(onBehalf);
    //     assertEq(borrowedBefore, borrowAmount, "Borrowed amount should be updated");

    //     // Alice approves repayment
    //     IERC20(mockUSDC).approve(address(lendingPool), repayShares);

    //     // Alice repays part of the loan
    //     lendingPool.repayByPosition(onBehalf, repayShares);

    //     // Get borrowed amount after repayment
    //     (, uint256 borrowedAfter,,) = lendingPool.getPosition(onBehalf);
    //     assertEq(borrowedAfter, borrowedBefore - repayShares, "Borrowed amount should decrease after repayment");

    //     console.log("Alice successfully repaid", repayShares);
    // }

    // function test_withdrawCollateralByPosition_InsufficientCollateral() public {
    //     uint256 supplyCollateralAmount = 1e5; // 1 WBTC as collateral
    //     uint256 supplyAmount = 100_000e6; // 100,000 USDC supply
    //     uint256 withdrawAmount = 1e6; // 1 WBTC withdrawal

    //     // Alice supplies liquidity
    //     vm.startPrank(alice);
    //     supplyLiquidity(supplyAmount);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     address onBehalf = address(createPosition());
    //     supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

    //     // Bob withdrawshis collateral
    //     vm.expectRevert(LendingPool.InsufficientCollateral.selector);
    //     withdrawCollateral(onBehalf, withdrawAmount);
    // }

    // function test_withdrawCollateralByPosition() public {
    //     uint256 supplyCollateralAmount = 1e6; // 1 WBTC as collateral
    //     uint256 supplyAmount = 100_000e6; // 100,000 USDC supply
    //     uint256 withdrawAmount = 1e6; // 1 WBTC withdrawal

    //     // Alice supplies liquidity
    //     vm.startPrank(alice);
    //     supplyLiquidity(supplyAmount);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     address onBehalf = address(createPosition());
    //     supplyCollateralByPosition(onBehalf, supplyCollateralAmount);
    //     (uint256 collateralAmount,,,) = lendingPool.getPosition(onBehalf);

    //     // Bob withdrawshis collateral
    //     withdrawCollateral(onBehalf, withdrawAmount);

    //     // Ensure collateral is reduced accordingly
    //     (uint256 newCollateralAmount,,,) = lendingPool.getPosition(onBehalf);
    //     assertEq(newCollateralAmount, collateralAmount - withdrawAmount, "Collateral withdrawal mismatch");
    //     vm.stopPrank();
    // }

    function test_flashLoan(uint256 _amount) private returns (uint256) {
        deal(address(mockUSDC), address(lendingPool), _amount);

        uint256 wbtc = PriceConverterLib.getConversionRate(_amount, usdcUsdPriceFeed, wbtcUsdPriceFeed);

        // encode parameter to bytes: address,uint256
        bytes memory params = abi.encode(address(this), _amount);

        lendingPool.flashLoan(address(mockUSDC), _amount, params);

        return wbtc;
    }

    // to receive flashloan
    function onFlashLoan(address token, uint256 amount, bytes calldata params) external {
        console.log("Flashloan received", amount);

        // decode parameter from bytes: address,uint256
        (address receiver, uint256 _amount) = abi.decode(params, (address, uint256));
        uint256 wbtc = PriceConverterLib.getConversionRate(_amount, usdcUsdPriceFeed, wbtcUsdPriceFeed);

        // mint
        mockWBTC.mint(receiver, wbtc);

        IERC20(token).approve(address(lendingPool), amount);
    }
}
