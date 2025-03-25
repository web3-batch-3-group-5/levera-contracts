// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {EventLib} from "./libraries/EventLib.sol";
import {LendingPool} from "./LendingPool.sol";
import {PositionType} from "./interfaces/ILendingPool.sol";
import {Vault} from "./Vault.sol";

contract LendingPoolFactory {
    error NotALendingPool();
    error PoolAlreadyCreated();
    error PoolNotFound();
    error Unauthorized();

    address public router;
    address public owner;
    mapping(bytes32 => address) public lendingPoolIds;
    mapping(address => bool) public lendingPools;
    mapping(bytes32 => address) public vaults;
    address[] public createdLendingPools;

    constructor(address _router) {
        owner = msg.sender;
        router = _router;
    }

    modifier canUpdate(address _lendingPool) {
        if (msg.sender != ILendingPool(_lendingPool).creator() && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier isExist(address _lendingPool) {
        if (!lendingPools[_lendingPool]) revert PoolNotFound();
        _;
    }

    function createLendingPool(
        address loanToken,
        address collateralToken,
        address loanTokenUsdDataFeed,
        address collateralTokenUsdDataFeed,
        uint256 liquidationThresholdPercentage,
        uint256 interestRate,
        PositionType positionType
    ) external returns (address) {
        bytes32 id = keccak256(abi.encode(loanToken, collateralToken));
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();

        address vaultAddress = vaults[id];
        if (vaultAddress == address(0)) {
            Vault newVault = new Vault(loanToken, collateralToken, address(this));
            vaultAddress = address(newVault);
            vaults[id] = vaultAddress;
        }

        LendingPool lendingPool = new LendingPool(
            IERC20(loanToken),
            IERC20(collateralToken),
            AggregatorV2V3Interface(loanTokenUsdDataFeed),
            AggregatorV2V3Interface(collateralTokenUsdDataFeed),
            router,
            liquidationThresholdPercentage,
            interestRate,
            positionType,
            msg.sender,
            vaultAddress
        );
        lendingPoolIds[id] = address(lendingPool);
        createdLendingPools.push(address(lendingPool));

        lendingPools[address(lendingPool)] = true;
        Vault(vaultAddress).setLendingPool(address(lendingPool), true);

        _indexLendingPool(address(lendingPool));
        emit EventLib.CreateLendingPool(address(lendingPool));

        return address(lendingPool);
    }

    function updateLendingPoolStatus(address _lendingPool, bool _status)
        public
        isExist(_lendingPool)
        canUpdate(_lendingPool)
    {
        lendingPools[_lendingPool] = _status;
        _indexLendingPool(_lendingPool);
    }

    function storeLendingPool(address _lendingPool) external {
        if (_lendingPool == address(0) || !isContract(_lendingPool)) revert NotALendingPool();
        if (lendingPools[_lendingPool]) revert PoolAlreadyCreated();

        LendingPool lendingPool = LendingPool(_lendingPool);
        address loanToken = address(lendingPool.loanToken());
        address collateralToken = address(lendingPool.collateralToken());

        if (loanToken == address(0) || collateralToken == address(0)) {
            revert NotALendingPool();
        }

        bytes32 id = lendingPool.contractId();
        if (lendingPoolIds[id] != address(0)) revert PoolAlreadyCreated();

        lendingPoolIds[id] = _lendingPool;
        lendingPools[_lendingPool] = true;

        _indexLendingPool(_lendingPool);
        emit EventLib.StoreLendingPool(_lendingPool);
    }

    function discardLendingPool(address _lendingPool) external isExist(_lendingPool) canUpdate(_lendingPool) {
        updateLendingPoolStatus(_lendingPool, false);

        LendingPool lendingPool = LendingPool(_lendingPool);
        bytes32 id = lendingPool.contractId();

        delete lendingPoolIds[id];
        delete lendingPools[_lendingPool];

        for (uint256 i = 0; i < createdLendingPools.length; i++) {
            if (createdLendingPools[i] == _lendingPool) {
                createdLendingPools[i] = createdLendingPools[createdLendingPools.length - 1];
                createdLendingPools.pop();
                break;
            }
        }

        emit EventLib.DiscardLendingPool(_lendingPool);
    }

    function _indexLendingPool(address _lendingPool) internal {
        address collateralToken = ILendingPool(_lendingPool).collateralToken();
        address loanToken = ILendingPool(_lendingPool).loanToken();
        address creator = ILendingPool(_lendingPool).creator();
        PositionType positionType = ILendingPool(_lendingPool).positionType();

        emit EventLib.AllLendingPool(
            _lendingPool, loanToken, collateralToken, uint8(positionType), creator, lendingPools[_lendingPool]
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
