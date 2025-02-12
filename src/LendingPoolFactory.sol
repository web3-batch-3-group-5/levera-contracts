// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PoolParams} from "./interfaces/ILendingPool.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {LendingPool} from "./LendingPool.sol";

contract LendingPoolFactory {
    error NotALendingPool();
    error PoolAlreadyCreated();
    error PoolNotFound();
    error Unauthorized();

    address public owner;
    mapping(bytes32 => address) public lendingPoolIds;
    mapping(address => PoolParams) public lendingPools;
    address[] public createdLendingPools;

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

    function createLendingPool(
        address loanToken,
        address collateralToken,
        address loanTokenUsdDataFeed,
        address collateralTokenUsdDataFeed
    ) external returns (address) {
        bytes32 id = keccak256(abi.encode(loanToken, collateralToken));
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();

        LendingPool lendingPool = new LendingPool(
            IERC20(loanToken),
            IERC20(collateralToken),
            AggregatorV2V3Interface(loanTokenUsdDataFeed),
            AggregatorV2V3Interface(collateralTokenUsdDataFeed)
        );
        lendingPoolIds[id] = address(lendingPool);
        createdLendingPools.push(address(lendingPool));

        string memory loanTokenName = getTokenName(loanToken);
        string memory collateralTokenName = getTokenName(collateralToken);
        string memory loanTokenSymbol = getTokenSymbol(loanToken);
        string memory collateralTokenSymbol = getTokenSymbol(collateralToken);

        lendingPools[address(lendingPool)] = PoolParams(
            loanToken,
            collateralToken,
            loanTokenUsdDataFeed,
            collateralTokenUsdDataFeed,
            loanTokenName,
            collateralTokenName,
            loanTokenSymbol,
            collateralTokenSymbol,
            address(this), // LendingPool is created by factory contract
            true
        );

        _indexLendingPool(address(lendingPool));

        emit EventLib.CreateLendingPool(address(lendingPool), lendingPools[address(lendingPool)]);

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

    function storeLendingPool(address _lendingPool) external {
        if (lendingPools[_lendingPool].creator != address(0)) revert PoolAlreadyCreated();
        if (_lendingPool == address(0) || !isContract(_lendingPool)) revert NotALendingPool();

        LendingPool lendingPool = LendingPool(_lendingPool);
        address loanToken = address(lendingPool.loanToken());
        address collateralToken = address(lendingPool.collateralToken());
        address loanTokenUsdDataFeed = address(lendingPool.loanTokenUsdDataFeed());
        address collateralTokenUsdDataFeed = address(lendingPool.collateralTokenUsdDataFeed());

        if (
            loanToken == address(0) || collateralToken == address(0) || loanTokenUsdDataFeed == address(0)
                || collateralTokenUsdDataFeed == address(0)
        ) {
            revert NotALendingPool();
        }

        bytes32 id = lendingPool.contractId();
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();
        lendingPoolIds[id] = _lendingPool;

        string memory loanTokenName = getTokenName(loanToken);
        string memory collateralTokenName = getTokenName(collateralToken);
        string memory loanTokenSymbol = getTokenSymbol(loanToken);
        string memory collateralTokenSymbol = getTokenSymbol(collateralToken);

        lendingPools[_lendingPool] = PoolParams(
            loanToken,
            collateralToken,
            loanTokenUsdDataFeed,
            collateralTokenUsdDataFeed,
            loanTokenName,
            collateralTokenName,
            loanTokenSymbol,
            collateralTokenSymbol,
            lendingPool.owner(),
            true
        );

        _indexLendingPool(_lendingPool);

        emit EventLib.StoreLendingPool(_lendingPool, lendingPools[_lendingPool]);
    }

    function discardLendingPool(address _lendingPool) external isExist(_lendingPool) canUpdate(_lendingPool) {
        updateLendingPoolStatus(_lendingPool, false);

        LendingPool lendingPool = LendingPool(_lendingPool);
        bytes32 id = lendingPool.contractId();

        delete lendingPoolIds[id];
        delete lendingPools[_lendingPool];

        emit EventLib.DiscardLendingPool(_lendingPool);
    }

    function _indexLendingPool(address _lendingPool) internal isExist(_lendingPool) {
        PoolParams memory pool = lendingPools[_lendingPool];

        emit EventLib.AllLendingPool(
            _lendingPool,
            pool.loanToken,
            pool.collateralToken,
            pool.loanTokenUsdDataFeed,
            pool.collateralTokenUsdDataFeed,
            pool.loanTokenName,
            pool.collateralTokenName,
            pool.loanTokenSymbol,
            pool.collateralTokenSymbol,
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

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
