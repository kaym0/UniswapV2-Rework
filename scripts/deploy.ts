import { Contract } from "ethers";
import { ethers } from "hardhat";
import { DreamSwapFactory } from "../typechain/DreamSwapFactory";
import { DreamSwapLiquidity } from "../typechain/DreamSwapLiquidity";
import { DreamSwapPair } from "../typechain/DreamSwapPair";


const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab"
}
 async function main() {
    /// const signers = await ethers.getSigners();
    /// const _accounts = signers;
    /// const accounts: string[] = _accounts.map((account) => account.address);

    /// Deploy factory
    const factory = await deployFactory();

    /// Deploy Libraries for Pair
    const lib = await deployLibraries();

    /// Deploy Pair Implementation
    const pair = await deployPairImplementation();

    /// Set PAIR implementation in Factory
    await factory.setImplementation(pair.address);

    /// Deploy Liquidity Management Contract
    const liquidity = await deployLiquidityManagement();

    /// Deploy Router
    const router = await deployRouter();

    console.log("Pair:                          ", pair.address);
    console.log("REACT_APP_FACTORY=             ", factory.address);
    console.log("REACT_APP_LIQUIDITY=           ", liquidity.address)
    console.log("REACT_APP_ROUTER=              ", router.address);



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
        const Pair = await ethers.getContractFactory("DreamSwapPair", {
            libraries: {
                Math: lib.address,
            },
        });

        const pair = await Pair.deploy();
        await pair.deployed();
        return pair;
    }

    async function deployFactory(): Promise<DreamSwapFactory | Contract> {
        const Factory = await ethers.getContractFactory("DreamSwapFactory");
        const factory = await Factory.deploy();

        await factory.deployed();

        return factory;
    }

    async function deployLiquidityManagement(): Promise<DreamSwapLiquidity | Contract> {
        const Liquidity = await ethers.getContractFactory("DreamSwapLiquidity");
        const liquidity = await Liquidity.deploy(factory.address, pair.address);
        await liquidity.deployed();

        return liquidity;
    }

    async function deployRouter() {
        const Router = await ethers.getContractFactory("DreamSwapRouter");
        const router = await Router.deploy(factory.address, WETH.address);
        await router.deployed();

        return router;
    }
    
    async function deployLibraries() {
        const Math = await ethers.getContractFactory("Math");
        const math = await Math.deploy();
        await math.deployed();

        return math;
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
