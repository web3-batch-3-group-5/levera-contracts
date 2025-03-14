// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";

/*
 * We cannot interact with Flame Block Explorer hence it's important to create REPL file for setup
 * 1) Create MockAggregator and pair token - aggregator
 * 2) Minting
 */
contract REPLMockDeploy is Script {
    struct MockConfig {
        address contractAddr;
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
    }

    MockConfig[] private mockTokens;
    // Arbitrum Sepolia
    address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x5D680e6aF2C03751b9aE474E5751781c594df210;
    address private constant MOCK_FACTORY_ADDR = 0x72BA07E6bc0b4eFC5b2069b816Ed40F64dc67C17;

    address private constant LA_DAI = 0x51a439096Ee300eC7a07FFd7Fa55a1f8723948c5;
    address private constant LA_USDC = 0xE6DFbEE9D497f1b851915166E26A273cB03F27E1;
    address private constant LA_USDT = 0xc0233309cD5e1fa340E2b681Dba3D4240aB6F49d;
    address private constant LA_WBTC = 0x472A3ec37E662b295fd25E3b5d805117345a89D1;
    address private constant LA_WETH = 0x06322002130c5Fd3a5715F28f46EC28fa99584bE;

    constructor() {
        // Arbitrum Sepolia
        mockTokens.push(MockConfig(LA_DAI, "Mock DAI", "laDAI", 18, 1e18));
        mockTokens.push(MockConfig(LA_USDC, "Mock USD Coin", "laUSDC", 6, 1e6));
        mockTokens.push(MockConfig(LA_USDT, "Mock USD Token", "laUSDT", 6, 1e6));
        mockTokens.push(MockConfig(LA_WBTC, "Mock Wrapped Bitcoin", "laWBTC", 8, 100_000e8));
        mockTokens.push(MockConfig(LA_WETH, "Mock Wrapped Ethereum", "laWETH", 18, 2_500e18));
    }

    function setupFlameMockUniswapRouter() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        MockFactory mockFactory = MockFactory(MOCK_FACTORY_ADDR);
        MockUniswapRouter mockUniswapRouter = MockUniswapRouter(MOCK_UNISWAP_ROUTER_ADDR);

        console.log("================ Configure Mock in Router =================");
        console.log("Mock Uniswap Router deployed at:", MOCK_UNISWAP_ROUTER_ADDR);
        for (uint256 i = 0; i < mockTokens.length; i++) {
            MockConfig memory token = mockTokens[i];
            // mockFactory.storeMockToken(token.name, token.symbol, token.contractAddr);

            // // Discard if exist
            // mockFactory.discardMockAggregator(token.name, token.symbol);

            // address priceFeed = mockFactory.createMockAggregator(token.name, token.symbol, token.decimals, token.price);
            bytes32 id = keccak256(abi.encode(token.name, token.symbol));
            address priceFeed = mockFactory.aggregators(id);

            mockUniswapRouter.setPriceFeed(token.contractAddr, priceFeed);
            console.log(
                string(
                    abi.encodePacked("[", token.symbol, "] Token: ", token.contractAddr, ", Aggregator: ", priceFeed)
                )
            );
        }
        console.log("===========================================================");
        vm.stopBroadcast();
    }

    function mintMockToken() public {
        address receiver = 0x2808Dc7E5eFC9409CdD6166E01ce44Ae9a84bb32;
        for (uint256 i = 0; i < mockTokens.length; i++) {
            address token = mockTokens[i].contractAddr;
            MockERC20 mockERC20 = MockERC20(token);
            mockERC20.mint(receiver, 10 ** 18);
            console.log(string(abi.encodePacked("Successfully mint ", mockTokens[i].symbol, " to Address: ", receiver)));
        }
    }

    function run() external {
        setupFlameMockUniswapRouter();
    }
}
