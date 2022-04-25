
import { ethers } from "hardhat";

async function main() {

    const lib = await deployLibraries()
    const Factory = await ethers.getContractFactory("ManaSwapFactory");
    const factory = await Factory.deploy();

    await factory.deployed();

    const Pair = await ethers.getContractFactory("ManaSwapPair", {
        libraries: {
            Math: lib.address
        }
    });
    const pair = await Pair.deploy();

    await pair.deployed();

    /// Set implementation in Factory

    await factory.setImplementation(pair.address);


    const token0 = await deployToken("Matic", "Matic");
    const token1 = await deployToken("Wrapped Ethereum", "Weth");


    const tokenPair = await factory.createPair(token0.address, token1.address);


    await getPairData(factory, token0, token1);



    console.log("Factory deployed to:     ", factory.address);
    console.log("Pair deployed to:        ", pair.address);



    async function deployToken(name: string, symbol: string) {
        const Token = await ethers.getContractFactory("TestToken");
        const token0 = await Token.deploy(name, symbol);
        await token0.deployed();
        return token0;
    }

    async function deployLibraries() {
        const Math = await ethers.getContractFactory("Math");
        const math = await Math.deploy();
        await math.deployed()

        return math;
    }

    async function getPairData(factory: any, token0: any, token1: any) {
        const pairAddress = await factory.getPair(token0.address, token1.address);

        const pair = Pair.attach(pairAddress);

        const pairName = await pair.name();

        console.log("Pair Name: " +  pairName)
    }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

