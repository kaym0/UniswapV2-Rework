import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Factory = await ethers.getContractFactory("ToknFactory");

    const factory = Factory.attach("0x260FfD7B9f4F3bD8773d5E4849656C808e37f9B8");

    const tx = await factory.createPair("0x0A4FE1afCD44EDF8309d5cee43DF537A1C810d9E", "0xcd16da4082BDF8470ee9236F599e904026f759F9");
    await tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
