import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Token = await ethers.getContractFactory("TestToken");

    const chung = Token.attach("0x0A4FE1afCD44EDF8309d5cee43DF537A1C810d9E");
    const dude =  Token.attach("0xcd16da4082BDF8470ee9236F599e904026f759F9");

    await approve(chung, "0x23eCC48EEEb54cb2878F8DeE2c128d45D07F13A5", "10000000000000000000000000000000000000000")
    await approve(chung, "0xa16264F1374a131EAf86169FD5787de0885e9591", "10000000000000000000000000000000000000000")
    await approve(dude, "0x23eCC48EEEb54cb2878F8DeE2c128d45D07F13A5", "10000000000000000000000000000000000000000")
    await approve(dude, "0xa16264F1374a131EAf86169FD5787de0885e9591", "10000000000000000000000000000000000000000")

    async function approve(token: any, address: string, amount: string) {
       const tx = await token.approve(address, amount);

       console.log('sending');
       await tx.wait();
       console.log('confirmed');

    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
