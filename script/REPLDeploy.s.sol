// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";
import {Vault} from "../src/Vault.sol";

/*
 * We cannot debug unverified contract hence it's important to create REPL file for setup
 */
contract REPLDeploy is Script {
    struct LendingPoolConfig {
        address loanToken;
        address collateralToken;
        address loanTokenPriceFeed;
        address collateralTokenPriceFeed;
        uint256 supplyAmount;
        PositionType positionType;
    }

    struct MintConfig {
        string symbol;
        address token;
        uint256 amount;
    }

    struct RegTokenConfig {
        string name;
        string symbol;
        address tokenAddr;
    }

    address MOCK_UNISWAP_ROUTER;
    address MOCK_VAULT;
    address MOCK_FACTORY;
    address POSITION_FACTORY;
    address LENDING_POOL_FACTORY;
    address LA_DAI;
    address LA_DAI_PRICE_FEED;
    address LA_USDC;
    address LA_USDC_PRICE_FEED;
    address LA_USDT;
    address LA_USDT_PRICE_FEED;
    address LA_WBTC;
    address LA_WBTC_PRICE_FEED;
    address LA_WETH;
    address LA_WETH_PRICE_FEED;

    LendingPoolConfig[] private lendingPoolSeeds;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory fullPath = string.concat(root, "/config.json");
        string memory json = vm.readFile(fullPath);
        string memory chain = "eduChainTestnet";

        MOCK_UNISWAP_ROUTER = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_UNISWAP_ROUTER"));
        MOCK_VAULT = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_VAULT"));
        MOCK_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".MOCK_FACTORY"));
        POSITION_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".POSITION_FACTORY"));
        LENDING_POOL_FACTORY = vm.parseJsonAddress(json, string.concat(".", chain, ".LENDING_POOL_FACTORY"));
        LA_DAI = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_DAI"));
        LA_DAI_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_DAI_PRICE_FEED"));
        LA_USDC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDC"));
        LA_USDC_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDC_PRICE_FEED"));
        LA_USDT = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDT"));
        LA_USDT_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_USDT_PRICE_FEED"));
        LA_WBTC = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WBTC"));
        LA_WBTC_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WBTC_PRICE_FEED"));
        LA_WETH = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WETH"));
        LA_WETH_PRICE_FEED = vm.parseJsonAddress(json, string.concat(".", chain, ".LA_WETH_PRICE_FEED"));
    }

    function _mintMockToken(string memory symbol, address tokenAddr, address receiver, uint256 amount) public {
        console.log(string.concat("Minting ", symbol, "..."));
        MockERC20 mockERC20 = MockERC20(tokenAddr);
        try mockERC20.mint(receiver, amount) {
            console.log(string.concat("Minted ", symbol), receiver);
        } catch {
            console.log("Minting failed");
        }
        console.log(string.concat("Balance ", symbol), mockERC20.balanceOf(receiver));
    }

    function _mintBulkMockTokens() public {
        address receiver = 0x7C7bcF1d605F3fEe8E61bCa7605b3007C8b389be;
        MintConfig[] memory configs = new MintConfig[](5);

        configs[0] = MintConfig("laDAI", LA_DAI, 10_000_000e18);
        configs[1] = MintConfig("laUSDC", LA_USDC, 10_000_000e6);
        configs[2] = MintConfig("laUSDT", LA_USDT, 10_000_000e6);
        configs[3] = MintConfig("laWBTC", LA_WBTC, 1_000e8);
        configs[4] = MintConfig("laWETH", LA_WETH, 40_000e18);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        for (uint256 i; i < configs.length; i++) {
            _mintMockToken(configs[i].symbol, configs[i].token, receiver, configs[i].amount);
        }

        vm.stopBroadcast();
    }

    function _reinputMockToken() internal {
        RegTokenConfig[] memory configs = new RegTokenConfig[](5);

        configs[0] = RegTokenConfig("Mock DAI", "laDAI", LA_DAI);
        configs[1] = RegTokenConfig("Mock USD Coin", "laUSDC", LA_USDC);
        configs[2] = RegTokenConfig("Mock USD Token", "laUSDT", LA_USDT);
        configs[3] = RegTokenConfig("Mock Wrapped Bitcoin", "laWBTC", LA_WBTC);
        configs[4] = RegTokenConfig("Mock Wrapped Ethereum", "laWETH", LA_WETH);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        MockFactory mockFactory = MockFactory(MOCK_FACTORY);

        for (uint256 i; i < configs.length; i++) {
            mockFactory.discardMockToken(configs[i].name, configs[i].symbol);
            mockFactory.storeMockToken(configs[i].name, configs[i].symbol, configs[i].tokenAddr);
        }

        vm.stopBroadcast();
    }

    function _supplyLendingPool(address lendingPoolAddr) internal {
        uint256 supplyAmount = 1000e6; // LaUSDC
        uint256 collateralReserve = 10_000e8; // LaWBTC -- need deposit for flashloan

        address loanToken = ILendingPool(lendingPoolAddr).loanToken();
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

        MockERC20(collateralToken).mint(address(this), collateralReserve);
        MockERC20(loanToken).mint(address(this), supplyAmount);
        MockERC20(collateralToken).mint(lendingPoolAddr, collateralReserve);
        MockERC20(loanToken).approve(lendingPoolAddr, supplyAmount);
        ILendingPool(lendingPoolAddr).supply(supplyAmount);
    }

    function _init() internal {
        uint256 baseCollateral = 1e6; // LaWBTC
        uint256 leverage = 200;

        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY");
        vm.startBroadcast(uint256(privateKey));
        // Create Lending Pool
        LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LENDING_POOL_FACTORY);
        address lendingPoolAddr = lendingPoolFactory.createLendingPool(
            LA_USDC, LA_WBTC, LA_USDC_PRICE_FEED, LA_WBTC_PRICE_FEED, 80, 5, PositionType.LONG
        );
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));

        // Supply Lending Pool for flashloan
        _supplyLendingPool(lendingPoolAddr);

        console.log("Lending Pool deployed at:", lendingPoolAddr);
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

        // Create Position
        PositionFactory positionFactory = PositionFactory(POSITION_FACTORY);
        MockERC20(collateralToken).approve(address(this), baseCollateral);
        MockERC20(collateralToken).approve(address(positionFactory), baseCollateral);
        console.log("Position Factory deployed at:", address(positionFactory));

        address onBehalf = positionFactory.createPosition(lendingPoolAddr, baseCollateral, leverage);
        console.log("Position deployed at:", onBehalf);

        // Destroy
        positionFactory.deletePosition(lendingPoolAddr, onBehalf);
        lendingPoolFactory.discardLendingPool(lendingPoolAddr);
        vm.stopBroadcast();
    }

    function _createBulkLendingPools() internal {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LENDING_POOL_FACTORY);
        Vault vault = Vault(MOCK_VAULT);

        lendingPoolSeeds.push(
            LendingPoolConfig(LA_USDC, LA_WBTC, LA_USDC_PRICE_FEED, LA_WBTC_PRICE_FEED, 500_000e6, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_USDC, LA_WETH, LA_USDC_PRICE_FEED, LA_WETH_PRICE_FEED, 500_000e6, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_USDT, LA_WBTC, LA_USDT_PRICE_FEED, LA_WBTC_PRICE_FEED, 500_000e6, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_USDT, LA_WETH, LA_USDT_PRICE_FEED, LA_WETH_PRICE_FEED, 500_000e6, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_DAI, LA_WBTC, LA_DAI_PRICE_FEED, LA_WBTC_PRICE_FEED, 500_000e18, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_DAI, LA_WETH, LA_DAI_PRICE_FEED, LA_WETH_PRICE_FEED, 500_000e18, PositionType.LONG)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_WBTC, LA_USDC, LA_WBTC_PRICE_FEED, LA_USDC_PRICE_FEED, 5e8, PositionType.SHORT)
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(LA_WETH, LA_USDT, LA_WETH_PRICE_FEED, LA_USDT_PRICE_FEED, 200e18, PositionType.SHORT)
        );

        for (uint256 i = 0; i < lendingPoolSeeds.length; i++) {
            LendingPoolConfig memory lendingPool = lendingPoolSeeds[i];
            address lendingPoolAddr = lendingPoolFactory.createLendingPool(
                lendingPool.loanToken,
                lendingPool.collateralToken,
                lendingPool.loanTokenPriceFeed,
                lendingPool.collateralTokenPriceFeed,
                80,
                5,
                lendingPool.positionType
            );
            console.log("Lending Pool deployed at:", lendingPoolAddr);

            address loanToken = ILendingPool(lendingPoolAddr).loanToken();
            address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();

            vault.setLendingPool(lendingPoolAddr, true);
            vault.setToken(loanToken, true);
            vault.setToken(collateralToken, true);

            MockERC20(loanToken).approve(lendingPoolAddr, lendingPool.supplyAmount);
            ILendingPool(lendingPoolAddr).supply(lendingPool.supplyAmount);
        }

        vm.stopBroadcast();
    }

    function run() external {
        // _mintBulkMockTokens();
        // _reinputMockToken();
        _createBulkLendingPools();
    }
}
