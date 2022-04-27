// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestWeth is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1_000_000_000 ether);
    }

    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit zero");
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    function addEth() public payable {
        /// This is just a way for this contract to receive ETH for testing with withdraw.
    }
}