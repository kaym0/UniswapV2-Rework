// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Create2.sol";
import "./interface/IDreamSwapPair.sol";
import "./utils/Operator.sol";

contract ToknFactory is Operator {

    string public suffix = "DLP"; // Dreamswap LP

    address public feeTo;

    uint256 public liquidityBaseFee = 30;

    address public _implementation;

    mapping (address => mapping(address => address)) public pairs;

    address[] private _allPairs;

    event PairCreated (address indexed token0, address indexed token1, address pair, uint256 index);
    event FeeChange (address indexed operator, uint256 indexed fee);


    /**
     *  @dev Returns all pairs as an array
     */
    function allPairs() public view returns (address[] memory) {
        return _allPairs;
    }

    /**
     *
     *  @dev Creates a new pair if one does not already exist
     *
     *  @notice Uses minimal proxy pattern and initialization in a single transaction to minimize gas fees while maxmizing functionality.
     *
     *  @param token0 - The address of token0
     *  @param token1 - The address of token1
     *
     *  @return pair - The new pair address
     *
     */
    function createPair(address token0, address token1) public returns (address pair) {
        require(_getExistingPair(token0, token1) == address(0), "Pair already exists");

        //(address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        // Create minimal proxy 
        pair  = _createMinimalProxy(_implementation, token0, token1);

        // Encode initialization data
        bytes memory data = _encodeData(token0, token1);

        // Initialize Pair contract
        IDreamSwapPair(pair).init(data);

        // Map pair address to both possible inputs
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        _allPairs.push(pair);

        // Emit event stating new pair exists
        emit PairCreated (token0, token1, pair, _allPairs.length);
    }

    /**
     *  @dev Gets the address of a pairing of token0 and token1 if it exists.
     *  @notice Tokens do not need to be in correct order for this to work
     *  @return pair - the pair address
     */
    function getPair(address token0, address token1) public view returns (address pair) {
        pair = _getExistingPair(token0, token1);
    }

    /**
     *  @dev Sets the implementation contract. This is the contract which is cloned as a minimal proxy.
     */
    function setImplementation(address implementation_) public onlyOperator {
        _implementation = implementation_;
    }

    /**
     *  @dev Updates the pair token name suffix. This is cosmetic only.
     */
    function updatePairSuffix(string memory _suffix) public onlyOperator {
        suffix = _suffix;
    }

    function updateFeeTo(address account) public onlyOperator {
        feeTo = account;
    }
    
    /**
     *
     *  @dev Updates the liquidity providing fee which is dispersed between LPs.
     *
     *  @notice This can be set to a maximum of 5%, but the intention is that it will never be close to that high.
     *
     */
    function updateLiquidityBaseFee(uint256 fee) public onlyOperator {
        require(fee <= 500, "Fee cannot be larger than 5%");

        liquidityBaseFee = fee;

        emit FeeChange(msg.sender, fee);
    }

    /**
     *
     *  @dev Checks if a pair exists by checking both combinations of token ordering.
     *
     *  @notice This returns the zero address if no pair is found.
     *
     *  @return pair - The pair address
     *
     */
    function _getExistingPair(address token0, address token1) internal view returns (address pair) {
        if (pairs[token0][token1] != address(0)) return pairs[token0][token1];

        if (pairs[token1][token0] != address(0)) return pairs[token1][token0];

        return address(0);
    }

    /**
     *
     *  @dev Creates a ERC1167 minimal proxy of DreamSwap pair. This is only called in @createPair
     *
     *  @notice Pair contracts are not initialized by default
     *
     *  @param implementation - The implementation contract to clone
     *
     *  @return pair - The newly created pair address
     *
     */
    function _createMinimalProxy(address implementation, address token0, address token1) internal returns (address pair) {
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            pair := create2(0, ptr, 0x37, salt)
        }

        require(pair != address(0), "Contract failed to deploy.");
    }


    function computeAndSaltAddress(address implementation, address token0, address token1) public view returns (address, bytes32) {
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        return computeAddress(salt, implementation);
    }

    function computeAddress(bytes32 salt, address implementation)
        public
        view
        returns (address, bytes32)
    {
        return(
            Create2.computeAddress(
                salt,
                keccak256(getContractCreationCode(implementation)),
                address(this)
            ),  keccak256(getContractCreationCode(implementation)));
    }

    function getContractCreationCode(address logic)
        internal
        pure
        returns (bytes memory)
    {
        bytes10 creation = 0x3d602d80600a3d3981f3;
        bytes10 prefix = 0x363d3d373d3d3d363d73;
        bytes20 targetBytes = bytes20(logic);
        bytes15 _suffix = 0x5af43d82803e903d91602b57fd5bf3;
        return abi.encodePacked(creation, prefix, targetBytes, _suffix);
    }

    function getHashedCode(address logic) public pure returns (bytes32) {
        return keccak256(getContractCreationCode(logic));
    }

    function at(address addr) public view returns (bytes memory code) {
            assembly {
                // retrieve the size of the code, this needs assembly
                let size := extcodesize(addr)
                // allocate output byte array - this could also be done without assembly
                // by using code = new bytes(size)
                code := mload(0x40)
                // new "memory end" including padding
                mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
                // store length in memory
                mstore(code, size)
                // actually retrieve the code, this needs assembly
                extcodecopy(addr, add(code, 0x20), 0, size)
            }
        }

    /**
     *
     *  @dev ABI Encodes token data to pass into intializer function for newly created pair contracts
     *
     *  @notice The 4th and 5th arguments here are required only due to minimal proxy lacking initial state variables
     *
     *  @param token0 - The address of token0
     *  @param token1 - The address of token1
     *
     *  @return data - ABI-encoded data to use when initializing pair contracts.
     */
    function _encodeData(address token0, address token1) internal view returns (bytes memory) {
        uint256 unlocked = 1;
        return abi.encode(
            address(this), 
            token0, 
            token1, 
            true, 
            unlocked
        );
    }
}