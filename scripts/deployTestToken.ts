import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Token = await ethers.getContractFactory("TestToken");

    const chung = await Token.deploy("Chung", "Chungus");
    await chung.deployed();

    const dude = await Token.deploy("Vampire Survivors", "VAMPS");
    await dude.deployed();

    console.log("TokenA:             ", chung.address);
    console.log("TokenB:             ", dude.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
