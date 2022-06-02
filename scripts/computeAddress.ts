import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Factory = await ethers.getContractFactory("ToknFactory");

    const factory = Factory.attach("0x260FfD7B9f4F3bD8773d5E4849656C808e37f9B8");
    const token0 = "0x0A4FE1afCD44EDF8309d5cee43DF537A1C810d9E"
    const token1 = "0xcd16da4082BDF8470ee9236F599e904026f759F9";


    const getPair = await factory.getPair(token0, token1);

    const addr = await factory.computeAndSaltAddress("0x6d92188a5f1425e114bbcbfbf7d65Aa2FAEE486E", token0, token1);
    console.log(getPair);
    console.log(addr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
