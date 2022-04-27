import { ethers } from "hardhat";
import { TestToken } from "../typechain";

async function main() {
    const signers = await ethers.getSigners();
    const _accounts = signers;
    const accounts: string[] = _accounts.map((account) => account.address);

    const lib = await deployLibraries();
    const Factory = await ethers.getContractFactory("DreamSwapFactory");
    const factory = await Factory.deploy();

    await factory.deployed();

    const Pair = await ethers.getContractFactory("DreamSwapPair", {
        libraries: {
            Math: lib.address,
        },
    });

    const pair = await Pair.deploy();
    await pair.deployed();

    console.log("Pair implementation deployed");

    /// Set PAIR implementation in Factory
    await factory.setImplementation(pair.address);

    //// Deploy some sample tokens
    const token0 = await deployToken("WMatic", "Matic");
    const token1 = await deployToken("Chainlink", "Link");
    const WETH = await deployToken("Wrapped Ethereum", "WETH");

    //// Create First Pair using Wmatic and Chainlink
    await createPair(token0, token1);

    //// Get Pair Data for Testing
    await getPairData(factory, token0, token1);

    ////  Deploy Router
    const router = await deployRouter();

    //// Deploy Liquidity Dreamgement Contract
    const liquidity = await deployLiquidityManagement();

    //// Approve Liquidity Dreamger to Move Tokens
    await approveTokens([token0, token1, WETH], liquidity.address);

    //// Add liquidity
    await addLiquidity(token0, token1);

    //// Fetch pair data after adding liquidity

    await getPairData(factory, token0, token1);

    await testSwap(factory, token0, token1);

    //// Log Contract Deployments
    console.log("");
    console.log("--------------------------------------------");
    console.log("");
    console.log("WMATIC deployed to:            ", token0.address);
    console.log("ChainLink deployed to:         ", token1.address);
    console.log("WETH deployed to:              ", WETH.address);
    console.log("Factory deployed to:           ", factory.address);
    console.log("Pair deployed to:              ", pair.address);
    console.log("Router                         ", router.address);
    console.log("Liquidity Maagement            ", liquidity.address);

    async function createPair(token0: TestToken, token1: TestToken) {
        const tx = await factory.createPair(token0.address, token1.address);
        await tx.wait();
        console.log("Pair created");
    }

    async function addLiquidity(token0: TestToken, token1: TestToken) {
        const tx = await liquidity.addLiquidity(
            token0.address,
            token1.address,
            toWei("100000"),
            toWei("100000"),
            toWei("100000"),
            toWei("100000"),
            accounts[0],
            Math.floor(Date.now() / 1000 + 3600).toString()
        );

        await tx.wait();

        console.log("Liquidity added");
    }

    async function deployLiquidityManagement() {
        const Liquidity = await ethers.getContractFactory("DreamSwapLiquidity");
        const liquidity = await Liquidity.deploy(factory.address, pair.address);
        await liquidity.deployed();
        console.log("Liquidity management deployed");
        return liquidity;
    }

    async function deployRouter() {
        const Router = await ethers.getContractFactory("DreamSwapRouter");
        const router = await Router.deploy(factory.address, WETH.address);
        await router.deployed();
        console.log("Router deployed");
        return router;
    }

    async function deployToken(name: string, symbol: string) {
        const Token = await ethers.getContractFactory("TestToken");
        const token0 = await Token.deploy(name, symbol);
        await token0.deployed();
        console.log("Token deployed");
        return token0;
    }

    async function deployLibraries() {
        const Math = await ethers.getContractFactory("Math");
        const math = await Math.deploy();
        await math.deployed();

        console.log("Librarys deployed");

        return math;
    }

    async function getPairData(factory: any, token0: any, token1: any) {
        const pairAddress = await factory.getPair(token0.address, token1.address);
        const pair = Pair.attach(pairAddress);
        const pairName = await pair.name();
        const reserveBalances = await pair.getReserveBalances();
        const balances = await pair.getBalances();
        const balanceOfLP = await pair.balanceOf(accounts[0]);
        console.log("");
        console.log("Pair Name:          " + pairName);
        console.log("Pair Balance:       " + reserveBalances);
        console.log("Pair Real Balances: " + balances);
        console.log("LP Tokens owned:    " + balanceOfLP);
        console.log("Pair Address:       ", pairAddress);
        console.log("");
    }

    async function approveToken(token: any, approveAddress: string) {
        const tx = await token.approve(approveAddress, toWei("1000000000000000"));
        await tx.wait();
    }

    async function approveTokens(tokens: any[], approveAddress: string, iter: number = 0) {
        await approveToken(tokens[iter], approveAddress);

        let iterator = iter + 1;
        if (tokens.length > iterator) {
            await approveTokens(tokens, approveAddress, iterator);
        }
    }

    async function testSwap(factory: any, tokenA: TestToken, tokenB: TestToken) {
        // Approve router for tokens! IMPORTANT.
        await approveTokens([tokenA], router.address);
        await approveTokens([tokenB], router.address);
        const path = [tokenB.address, tokenA.address];
        const amountIn = toWei("10000");

        const amountsOut = await router.getAmountsOut(amountIn, path);

        const amountOutMin = amountsOut;

        const deadline = (Math.floor(Date.now() / 1000) + 3600).toString();

        await checkAccountBalance(tokenA, tokenB);
        await checkPairBalance(tokenA, tokenB);
        await checkRouterBalances(tokenA, tokenB);
        await checkFactoryBalances(tokenA, tokenB);

        const tx = await router.swapExactTokensForTokens(
            amountIn,
            amountOutMin[1],
            path,
            accounts[0],
            deadline
        );

        await tx.wait();

        await checkAccountBalance(tokenA, tokenB);
        await checkPairBalance(tokenA, tokenB);
        await checkRouterBalances(tokenA, tokenB);
        await checkFactoryBalances(tokenA, tokenB);
    }

    async function checkFactoryBalances(tokenA: TestToken, tokenB: TestToken) {
        const balanceA = await tokenA.balanceOf(factory.address);
        const balanceB = await tokenB.balanceOf(factory.address);
        console.log("");
        console.log("Factory Balances");
        console.log("BalanceA:           ", fromWei(balanceA.toString()));
        console.log("BalanceB:           ", fromWei(balanceB.toString()));
        console.log("");
        console.log("");
    }

    async function checkRouterBalances(tokenA: TestToken, tokenB: TestToken) {
        const balanceA = await tokenA.balanceOf(router.address);
        const balanceB = await tokenB.balanceOf(router.address);
        console.log("");
        console.log("Router Balances");
        console.log("BalanceA:           ", fromWei(balanceA.toString()));
        console.log("BalanceB:           ", fromWei(balanceB.toString()));
        console.log("");
        console.log("");
    }

    async function checkPairBalance(tokenA: TestToken, tokenB: TestToken) {
        const pairAddress = await factory.getPair(tokenA.address, tokenB.address);
        const balanceA = await tokenA.balanceOf(pairAddress);
        const balanceB = await tokenB.balanceOf(pairAddress);

        console.log("");
        console.log("Pair Balances");
        console.log("BalanceA:           ", fromWei(balanceA.toString()));
        console.log("BalanceB:           ", fromWei(balanceB.toString()));
        console.log("");
        console.log("");
    }

    async function checkAccountBalance(tokenA: TestToken, tokenB: TestToken) {
        const balanceA = await tokenA.balanceOf(accounts[0]);
        const balanceB = await tokenB.balanceOf(accounts[0]);

        console.log("");
        console.log("User Balances");
        console.log("BalanceA:           ", fromWei(balanceA.toString()));
        console.log("BalanceB:           ", fromWei(balanceB.toString()));
        console.log("");
        console.log("");
    }

    async function deployDreamLibrary() {
        const DreamSwapLibrary = await ethers.getContractFactory("DreamSwapLibrary");
        const library = await DreamSwapLibrary.deploy();
        await library.deployed();
        return library;
    }
}

export const toWei = (amount: string | number) => {
    return ethers.utils.parseUnits(amount.toString(), "18");
};

export const fromWei = (amount: string | number) => {
    return ethers.utils.formatUnits(amount, "18");
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
