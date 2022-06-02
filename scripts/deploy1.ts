import { Contract } from "ethers";
import { ethers } from "hardhat";
import { DreamSwapFactory } from "../typechain/DreamSwapFactory";
import { DreamSwapLiquidity } from "../typechain/DreamSwapLiquidity";
import { DreamSwapPair } from "../typechain/DreamSwapPair";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};
async function main() {
    /// const signers = await ethers.getSigners();
    /// const _accounts = signers;
    /// const accounts: string[] = _accounts.map((account) => account.address);

    /// Deploy factory
    const factory = await deployFactory();

    /// Deploy Libraries for Pair
    /// const lib = await deployLibraries();

    /// Deploy Pair Implementation
    const pair = await deployPairImplementation();

    /// Set PAIR implementation in Factory
    await factory.setImplementation(pair.address);


    const compute = await deployCompute();

    const creationCodeHash = await compute.getHashedCode(pair.address);
    const creationCodeHashFactory = await factory.getHashedCode(pair.address);

    console.log("Pair:                          ", pair.address);
    console.log("REACT_APP_FACTORY=             ", factory.address);
    console.log("Init Code Hash:                ", creationCodeHash)
    console.log("Factory Code Hash:             ", creationCodeHashFactory)

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////

    async function deployPairImplementation(): Promise<DreamSwapPair | Contract> {
        /*
        const Pair = await ethers.getContractFactory("DreamSwapPair", {
            libraries: {
                Math: lib.address,
            },
        });
        */
        const Pair = await ethers.getContractFactory("ToknPair");
        const pair = await Pair.deploy();
        await pair.deployed();
        return pair;
    }

    async function deployFactory(): Promise<Contract> {
        const Factory = await ethers.getContractFactory("ToknFactory");
        const factory = await Factory.deploy();

        await factory.deployed();

        return factory;
    }

    async function deployCompute(): Promise<Contract> {
        const Compute = await ethers.getContractFactory("Compute");
        const compute = await Compute.deploy();

        await factory.deployed();

        return compute;
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
