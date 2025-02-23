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
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {Deploy} from "../script/Deploy.s.sol";

contract IntegrationTest is Test {
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    LendingPool public lendingPool;
    LendingPoolFactory public lendingPoolFactory;
    PositionFactory public positionFactory;
    MockFactory public mockFactory;

    uint8 public DECIMALS = 8;
    int64 public constant USDC_USD_PRICE = 1e8;
    int64 public constant WBTC_USD_PRICE = 1e13;
    uint8 liquidationThresholdPercentage = 80;
    uint8 interestRate = 5;
    PositionType positionType = PositionType.LONG;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Setup Factory
        Deploy deployScript = new Deploy();
        (lendingPoolFactory, positionFactory, mockFactory) = deployScript.deployFactory();
        lendingPoolFactory = lendingPoolFactory;
        positionFactory = positionFactory;
        mockFactory = mockFactory;

        // Setup WBTC - USDC lending pool
        (address loanToken, address loanTokenAggregator) =
            mockFactory.createMock("usdc", "USDC", DECIMALS, USDC_USD_PRICE);
        (address collateralToken, address collateralTokenAggregator) =
            mockFactory.createMock("wbtc", "WBTC", DECIMALS, WBTC_USD_PRICE);
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
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Position Factory deployed at:", address(positionFactory));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log("==============================================================");

        mockUSDC.mint(alice, 200_000e6);
        mockWBTC.mint(alice, 1e6);
        mockUSDC.mint(bob, 200_000e6);
        mockWBTC.mint(bob, 2e6);

        // Alice supply liquidity
        vm.startPrank(alice);
        supplyLiquidity(50_000e6);
        vm.stopPrank();

        // Alice supply liquidity
        vm.startPrank(bob);
        supplyLiquidity(50_000e6);
        vm.stopPrank();
    }

    function supplyLiquidity(uint256 amount) internal {
        IERC20(mockUSDC).approve(address(lendingPool), amount);
        lendingPool.supply(amount);
    }

    function supplyCollateralByPosition(address onBehalf, uint256 amount) internal {
        IERC20(mockWBTC).approve(address(lendingPool), amount);
        lendingPool.supplyCollateralByPosition(onBehalf, amount);
    }

    function withdrawCollateral(address onBehalf, uint256 amount) internal {
        lendingPool.withdrawCollateralByPosition(onBehalf, amount);
    }

    function test_createPosition() public {
        // Alice create position
        uint256 baseCollateral = 1e6;
        uint8 leverage = 2;

        vm.startPrank(alice);
        address onBehalf = address(positionFactory.createPosition(address(lendingPool), baseCollateral, leverage));
        vm.stopPrank();

        assertTrue(positionFactory.positions()[onBehalf], "Position is registered in Position Factory");
        assertEq(
            IPosition(onBehalf).effectiveCollateral(),
            baseCollateral * leverage,
            "Effective Collateral should be equal to Base Collateral multiplied by Leverage"
        );
        assertTrue(IPosition(onBehalf).borrowShares() > 0, "Borrow Share should be more than zero");
    }

    function test_position() public {
        uint256 baseCollateral = 1e6;
        uint8 leverage = 2;
        address positionAddress = positionFactory.createPosition(address(lendingPool), baseCollateral, leverage);
        Position position = Position(positionAddress);
        // assertEq(position.lendingPool(), address(lendingPool), "Position should have correct lending pool");
        // assertEq(position.baseCollateral(), address(mockWBTC), "Position should have correct collateral token");
        // assertEq(position.loanToken(), address(mockUSDC), "Position should have correct loan token");
        console.log("Position created at", address(position));
    }

    function test_supplyChange() public {
        uint256 bobBorrowAmount = 20_000e6;
        uint256 bobCollateralAmount = 1e6;

        // Bob Borrow
        vm.startPrank(bob);
        IERC20(mockWBTC).approve(address(lendingPool), bobCollateralAmount);
        address onBehalf = address(lendingPool.createPosition());
        lendingPool.supplyCollateralByPosition(onBehalf, bobCollateralAmount);

        uint256 collateralAmount =
            PriceConverterLib.getConversionRate(bobCollateralAmount, wbtcUsdPriceFeed, usdcUsdPriceFeed);

        console.log("Bob's Collateral Amount", collateralAmount);

        lendingPool.borrowByPosition(address(onBehalf), bobBorrowAmount);
        vm.stopPrank();

        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("Alice userSupplyShares =", lendingPool.userSupplyShares(alice));

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
    }

    function test_supplyCollateralByPosition_NoActivePosition() public {
        uint256 supplyCollateralAmount = 100_000e6;
        address randomOnBehalf = address(0x1234567890123456789012345678901234567890);

        vm.expectRevert(LendingPool.NoActivePosition.selector);
        lendingPool.supplyCollateralByPosition(randomOnBehalf, supplyCollateralAmount);
    }

    function test_supplyCollateralByPosition() public {
        uint256 supplyCollateralAmount = 1e6;

        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

        // Alice supply colleteral
        lendingPool.supplyCollateralByPosition(address(onBehalf), supplyCollateralAmount);

        (uint256 collateralAmount,,,) = lendingPool.getPosition(onBehalf);

        // Verify Alice's supply collateral
        assertEq(collateralAmount, supplyCollateralAmount, "Total Supply Collateral Should Be Update");

        console.log("collateral amount", collateralAmount);
    }

    function test_borrowByPosition() public {
        uint256 supplyCollateralAmount = 1e6; // in wbtc
        uint256 borrowAmount = 10e6; // in usdc

        // Bob supply to lending pool
        uint256 bobDeposit = 1000e6;
        vm.startPrank(bob);
        IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

        lendingPool.supply(bobDeposit);
        vm.stopPrank();

        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

        // Check Alice balance Before
        uint256 aliceBalanceBefore = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceBefore, 100_000e6, "Alice Balance Initial");

        // Alice supply collateral
        lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

        // Get initial position data
        (uint256 initialCollateral, uint256 initialBorrowed,,) = lendingPool.getPosition(onBehalf);

        // Ensure collateral was supplied correctly
        assertEq(initialCollateral, supplyCollateralAmount, "Collateral amount should be updated");
        assertEq(initialBorrowed, 0, "Initial borrowed amount should be zero");

        // Alice attempts to borrow
        lendingPool.borrowByPosition(onBehalf, borrowAmount);

        // Get updated position data
        (uint256 finalCollateral, uint256 finalBorrowed,,) = lendingPool.getPosition(onBehalf);

        // Verify borrow updates
        assertEq(finalCollateral, supplyCollateralAmount, "Collateral should remain the same");
        assertEq(finalBorrowed, borrowAmount, "Borrowed amount should be updated");

        // Check token balance
        uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore += borrowAmount, "Alice should receive the borrowed tokens");

        console.log("Alice successfully borrowed", aliceBalanceBefore += borrowAmount);
    }

    function test_borrowByCollateral_InsufficientCollateral() public {
        uint256 supplyCollateralAmount = 1e4;
        uint256 borrowAmount = 2000e6; // More than allowed

        // Bob supply to lending pool
        uint256 bobDeposit = 3000e6;
        vm.startPrank(bob);
        IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

        lendingPool.supply(bobDeposit);
        vm.stopPrank();

        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

        // Alice supply collateral
        lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

        // Expect revert due to insufficient collateral
        vm.expectRevert(LendingPool.InsufficientCollateral.selector);
        lendingPool.borrowByPosition(onBehalf, borrowAmount);
    }

    function test_borrowByCollateral_InsufficientLiquidity() public {
        uint256 supplyCollateralAmount = 1e6;
        uint256 borrowAmount = 100e6;

        // Bob supply to lending pool
        uint256 bobDeposit = 30e6; // less than borrowed amount
        vm.startPrank(bob);
        IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

        lendingPool.supply(bobDeposit);
        vm.stopPrank();

        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

        // Alice supply collateral
        lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

        // Expect revert due to insufficient liquidity
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        lendingPool.borrowByPosition(onBehalf, borrowAmount);
    }

    function test_repayByPosition() public {
        uint256 supplyCollateralAmount = 1e6;
        uint256 borrowAmount = 5e5;
        uint256 repayShares = 2e5;

        // Bob supply to lending pool
        uint256 bobDeposit = 30e6; // less than borrowed amount
        vm.startPrank(bob);
        IERC20(mockUSDC).approve(address(lendingPool), bobDeposit);

        lendingPool.supply(bobDeposit);
        vm.stopPrank();

        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        IERC20(mockWBTC).approve(address(lendingPool), supplyCollateralAmount);

        // Alice supplies collateral
        lendingPool.supplyCollateralByPosition(onBehalf, supplyCollateralAmount);

        // Alice borrows funds
        lendingPool.borrowByPosition(onBehalf, borrowAmount);

        // Get borrowed amount before repayment
        (, uint256 borrowedBefore,,) = lendingPool.getPosition(onBehalf);
        assertEq(borrowedBefore, borrowAmount, "Borrowed amount should be updated");

        // Alice approves repayment
        IERC20(mockUSDC).approve(address(lendingPool), repayShares);

        // Alice repays part of the loan
        lendingPool.repayByPosition(onBehalf, repayShares);

        // Get borrowed amount after repayment
        (, uint256 borrowedAfter,,) = lendingPool.getPosition(onBehalf);
        assertEq(borrowedAfter, borrowedBefore - repayShares, "Borrowed amount should decrease after repayment");

        console.log("Alice successfully repaid", repayShares);
    }

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
}
