import { ethers } from "hardhat";

const WETH = {
    // Rinkeby
    address: "0xc778417e063141139fce010982780140aa0cd5ab",
};

async function main() {
    const Token = await ethers.getContractFactory("TestToken");

    const chung = Token.attach("0x720bA4C9FB1D9c3C6e23c094313945D1eDBd2dE2");
    const dude =  Token.attach("0x6925Fcd5920D7B7Cbd608E9F4df51247627C2E33");

    await approve(chung, "0xCEaa1752C19392e512Ae4F6513F396D4c3E78160", "10000000000000000000000000000000000000000")
    await approve(chung, "0x4560935f651849640162DBeF3639729D2d1E0ebD", "10000000000000000000000000000000000000000")
    await approve(dude, "0xCEaa1752C19392e512Ae4F6513F396D4c3E78160", "10000000000000000000000000000000000000000")
    await approve(dude, "0x4560935f651849640162DBeF3639729D2d1E0ebD", "10000000000000000000000000000000000000000")

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
