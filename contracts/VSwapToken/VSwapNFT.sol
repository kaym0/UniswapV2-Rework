// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../token/ERC721/ERC721.sol";

contract RewardVault is ERC721 {
    constructor() ERC721("VSwapNFT", "VNFT") {

    }
}