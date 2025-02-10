// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {LendingPool, LendingPosition} from "../src/LendingPool.sol";
import {Position} from "../src/interfaces/ILendingPosition.sol";
import {PriceConverterLib} from "../src/libraries/PriceConverterLib.sol";

contract LendingPoolTest is Test {
    ERC20Mock public mockUSDC;
    ERC20Mock public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    LendingPool public lendingPool;

    uint8 public DECIMALS = 8;
    int64 public constant USDC_USD_PRICE = 1e8;
    int64 public constant WBTC_USD_PRICE = 1e13;

    mapping(address => mapping(address => Position)) public userPositions;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        mockUSDC = new ERC20Mock();
        mockWBTC = new ERC20Mock();
        usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        wbtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);

        lendingPool = new LendingPool(mockUSDC, mockWBTC, usdcUsdPriceFeed, wbtcUsdPriceFeed);

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("==============================================================");

        mockUSDC.mint(alice, 100_000e6);
        mockWBTC.mint(alice, 1e6);
        mockUSDC.mint(bob, 100_000e6);
        mockWBTC.mint(bob, 2e6);
    }

    function test_supply() public {
        uint256 initialDeposit = 100_000e6;
        uint256 bobBorrowAmount = 20_000e6;
        uint256 bobCollateralAmount = 1e6;

        // Alice deposit
        vm.startPrank(alice);
        IERC20(mockUSDC).approve(address(lendingPool), initialDeposit);

        // Alice supply to lending pool
        lendingPool.supply(initialDeposit);
        vm.stopPrank();

        // Verify Alice's balance in LendingPool
        uint256 aliceShares = lendingPool.userSupplyShares(alice);
        assertEq(aliceShares, initialDeposit, "Alice should receive correct shares");

        // Verify LendingPool's totalSupplyAssets
        assertEq(lendingPool.totalSupplyAssets(), initialDeposit, "Total supply should update");

        // Ensure LendingPool received USDC
        assertEq(IERC20(mockUSDC).balanceOf(address(lendingPool)), initialDeposit, "LendingPool should receive USDC");

        // Check Alice's USDC balance (should decrease)
        uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceAfter, 0, "Alice should have no USDC left after supplying");

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

    function test_create_position() public {
        // Alice create position
        vm.startPrank(alice);
        address onBehalf = address(lendingPool.createPosition());
        (uint256 collateralAmount, uint256 borrowedAmount,, bool isActive) = lendingPool.getPosition(onBehalf);
        vm.stopPrank();

        assertEq(collateralAmount, 0);
        assertEq(borrowedAmount, 0);
        assertTrue(isActive);
    }

    function test_SupplyCollateral_NoPosition() public {
        uint256 supplyCollateralAmount = 100_000e6;
        address randomOnBehalf = address(0x1234567890123456789012345678901234567890);

        vm.expectRevert(LendingPool.NoActivePosition.selector);
        lendingPool.supplyCollateralByPosition(randomOnBehalf, supplyCollateralAmount);
    }

    function test_supply_colateral() public {
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

    function test_borrow_by_position() public {
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

    function test_borrow_exceeds_collateral() public {
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

    function test_borrow_insuficientLiquid_collateral() public {
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

    function test_repay_by_position() public {
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
}
