// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {LendingPool} from "./LendingPool.sol";

// Immutable values
struct BasePoolParams {
    address loanToken;
    address collateralToken;
    address loanTokenUsdDataFeed;
    address collateralTokenUsdDataFeed;
}

// Mutable values
struct PoolParams {
    BasePoolParams basePoolParams;
    string loanTokenName;
    string collateralTokenName;
    string loanTokenSymbol;
    string collateralTokenSymbol;
    address creator;
    bool isActive;
}

contract LendingPoolFactory {
    error PoolAlreadyCreated();
    error PoolNotFound();
    error Unauthorized();

    address public owner;
    mapping(bytes32 => address) public lendingPoolIds;
    mapping(address => PoolParams) public lendingPools;
    address[] public createdLendingPools;

    event AllLendingPool(
        address loanToken,
        address collateralToken,
        address loanTokenUsdDataFeed,
        address collateralTokenUsdDataFeed,
        string loanTokenName,
        string collateralTokenName,
        string loanTokenSymbol,
        string collateralTokenSymbol,
        address lendingPool,
        uint256 timestamp,
        address creator,
        bool isActive
    );

    constructor() {
        owner = msg.sender;
    }

    modifier canUpdate(address _lendingPool) {
        if (msg.sender != lendingPools[_lendingPool].creator || msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier isExist(address _lendingPool) {
        if (lendingPools[_lendingPool].creator == address(0)) revert PoolNotFound();
        _;
    }

    function createLendingPool(BasePoolParams calldata params) external returns (address) {
        bytes32 id = keccak256(abi.encode(params.loanToken, params.collateralToken));
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();

        LendingPool lendingPool = new LendingPool(
            IERC20(params.loanToken),
            IERC20(params.collateralToken),
            AggregatorV2V3Interface(params.loanTokenUsdDataFeed),
            AggregatorV2V3Interface(params.collateralTokenUsdDataFeed)
        );
        lendingPoolIds[id] = address(lendingPool);
        createdLendingPools.push(address(lendingPool));

        string memory loanTokenName = getTokenName(params.loanToken);
        string memory collateralTokenName = getTokenName(params.collateralToken);
        string memory loanTokenSymbol = getTokenSymbol(params.loanToken);
        string memory collateralTokenSymbol = getTokenSymbol(params.collateralToken);

        lendingPools[address(lendingPool)] = PoolParams(
            params, loanTokenName, collateralTokenName, loanTokenSymbol, collateralTokenSymbol, msg.sender, true
        );

        _indexLendingPool(address(lendingPool));

        return address(lendingPool);
    }

    function updateLendingPoolStatus(address _lendingPool, bool _status)
        public
        isExist(_lendingPool)
        canUpdate(_lendingPool)
    {
        lendingPools[_lendingPool].isActive = _status;
        _indexLendingPool(_lendingPool);
    }

    function storeLendingPool(BasePoolParams calldata params, address _lendingPool) public {
        bytes32 id = keccak256(abi.encode(params.loanToken, params.collateralToken));
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();

        string memory loanTokenName = getTokenName(params.loanToken);
        string memory collateralTokenName = getTokenName(params.collateralToken);
        string memory loanTokenSymbol = getTokenSymbol(params.loanToken);
        string memory collateralTokenSymbol = getTokenSymbol(params.collateralToken);

        lendingPoolIds[id] = _lendingPool;
        lendingPools[_lendingPool] = PoolParams(
            params, loanTokenName, collateralTokenName, loanTokenSymbol, collateralTokenSymbol, msg.sender, true
        );

        _indexLendingPool(_lendingPool);
    }

    function discardLendingPool(address _lendingPool) public isExist(_lendingPool) canUpdate(_lendingPool) {
        updateLendingPoolStatus(_lendingPool, false);

        bytes32 id = keccak256(
            abi.encode(
                lendingPools[_lendingPool].basePoolParams.loanToken,
                lendingPools[_lendingPool].basePoolParams.collateralToken
            )
        );

        delete lendingPoolIds[id];
        delete lendingPools[_lendingPool];
    }

    function _indexLendingPool(address _lendingPool) internal isExist(_lendingPool) {
        PoolParams memory pool = lendingPools[_lendingPool];

        emit AllLendingPool(
            pool.basePoolParams.loanToken,
            pool.basePoolParams.collateralToken,
            pool.basePoolParams.loanTokenUsdDataFeed,
            pool.basePoolParams.collateralTokenUsdDataFeed,
            pool.loanTokenName,
            pool.collateralTokenName,
            pool.loanTokenSymbol,
            pool.collateralTokenSymbol,
            _lendingPool,
            block.timestamp,
            pool.creator,
            pool.isActive
        );
    }

    function getTokenName(address _token) public view returns (string memory) {
        try ERC20(_token).name() returns (string memory tokenName) {
            return tokenName;
        } catch {
            return "Unknown"; // Fallback name if `name()` is not implemented
        }
    }

    function getTokenSymbol(address _token) public view returns (string memory) {
        try ERC20(_token).symbol() returns (string memory tokenSymbol) {
            return tokenSymbol;
        } catch {
            return "UNKNOWN"; // Fallback name if `symbol()` is not implemented
        }
    }
}
