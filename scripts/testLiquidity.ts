import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Liquidity = await ethers.getContractFactory("ToknLiquidity");

    const liquidity = Liquidity.attach("0xB57BbC3e27ddE58f2F925481Ab6Cf34508ffB1d2");
    const token0 = "0x0A4FE1afCD44EDF8309d5cee43DF537A1C810d9E"
    const token1 = "0xcd16da4082BDF8470ee9236F599e904026f759F9";


    const desiredA =  "55000000000000000000";
    const desiredB =  "55000000000000000000";
    const amountMinA = "0";
    const amountMinB = "0";
    const to = "0x6FdCa39C96497B628410a6c29d862Dbf8CBdF179";
    const deadline = (Math.floor(Date.now() / 1000) + 3600).toString();

    const tx = await liquidity.addLiquidity(
        token0, 
        token1,
        desiredA,
        desiredB,
        amountMinA,
        amountMinB,
        to,
        deadline
    );
    await tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
