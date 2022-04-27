import { expect } from "chai";
import { ethers } from "hardhat";
import { TestToken__factory } from "../typechain";
import { advanceTimeAndBlock, fromWei, toWei } from "./functions";

const zeroAddress: string = "0x0000000000000000000000000000000000000000";
const deadline: string = (Math.floor(Date.now() / 1000) + 600).toString();

describe("Main", function () {
    let Pair: any;
    let wmatic: any;
    let link: any;
    let weth: any;
    let factory: any;
    let mathlib: any;
    let pairImplementation: any;
    let pair: any;
    let router: any;
    let liquidity: any;

    let _accounts: any;
    let accounts: any;

    const advanceOneWeek = async (account: any, Fn: any) => {
        const oneWeek = 86400 * 7;
        await advanceTimeAndBlock(oneWeek, ethers);
        const amount = await Fn;
        return amount;
    };

    const advance = async (weeks: number) => {
        const time = 86400 * 7 * weeks;
        await advanceTimeAndBlock(time, ethers);
    };

    const deployContract = async (Factory: any, args: string[] | [] = []) => {
        const contract = await Factory.deploy(...args);
        await contract.deployed();
        return contract;
    };

    const deployToken = async (
        name: string,
        symbol: string,
        contractFactory: TestToken__factory
    ) => {
        const token = await contractFactory.deploy(name, symbol);
        await token.deployed();
        return token;
    };

    before(async () => {
        /// Pre-deploy required library
        const Math = await ethers.getContractFactory("Math");
        mathlib = await deployContract(Math);

        const Factory = await ethers.getContractFactory("DreamSwapFactory");
        const Token = await ethers.getContractFactory("TestToken");
        const Weth = await ethers.getContractFactory("TestWeth");
        Pair = await ethers.getContractFactory("DreamSwapPair", {
            libraries: {
                Math: mathlib.address,
            },
        });
        const Router = await ethers.getContractFactory("DreamSwapRouter");
        const Liquidity = await ethers.getContractFactory("DreamSwapLiquidity");

        /// Get signers
        [..._accounts] = await ethers.getSigners();
        /// Map addresses for easy access
        accounts = _accounts.map((account: any) => account.address);

        /// Deploy test tokens
        wmatic = await deployToken("Wrapped Matic", "Wmatic", Token);
        link = await deployToken("Chainlink", "Link", Token);
        weth = await deployContract(Weth, ["Wrapped Matic", "WMATIC"]);

        /// Deploy infrastructure
        factory = await deployContract(Factory);
        pairImplementation = await deployContract(Pair);
        router = await deployContract(Router, [factory.address, weth.address]);
        liquidity = await deployContract(Liquidity, [factory.address, weth.address]);

        /// Add some ETH to weth contract so withdraws work properly.
        await weth.connect(_accounts[9]).addEth({ value: toWei(99)});
    });

    describe("DreamSwapFactory", async () => {
        it("setImplementation", async () => {
            await factory.setImplementation(pairImplementation.address);
            const implementation = await factory._implementation();
            expect(implementation).to.equal(pairImplementation.address);
        });

        it("updatePairSuffix", async () => {
            await factory.updatePairSuffix("ZZZ");
            const suffix = await factory.suffix();
            expect(suffix).to.equal("ZZZ");
        });

        it("updateFeeTo", async () => {
            await factory.updateFeeTo(accounts[0]);
            const feeTo = await factory.feeTo();
            expect(feeTo).to.equal(accounts[0]);
        });

        it("createPair", async () => {
            await factory.createPair(wmatic.address, link.address);
        });

        describe("getPair", async () => {
            it("Gets valid pair successfully", async () => {
                const pairAddress = await factory.getPair(wmatic.address, link.address);
                expect(pairAddress).to.not.equal(zeroAddress);

                pair = Pair.attach(pairAddress);
            });

            it("Correctly gets invalid pair as zero address", async () => {
                const pair = await factory.getPair(wmatic.address, weth.address);
                expect(pair).to.equal(zeroAddress);
            });
        });
    });

    describe("DreamSwapLiquidity", async () => {
        before(async () => {
            await wmatic.approve(liquidity.address, toWei("10000000000000000000000000"));
            await link.approve(liquidity.address, toWei("10000000000000000000000000"));
            await weth.approve(liquidity.address, toWei("10000000000000000000000000"));
        });
        describe("addLiquidity", async () => {
            it("Successfully adds liquidity to an empty pool", async () => {
                const tx = await liquidity.addLiquidity(
                    wmatic.address,
                    link.address,
                    toWei("100"),
                    toWei("100"),
                    toWei("100"),
                    toWei("100"),
                    accounts[0],
                    deadline
                );

                await tx.wait();
                /// If this passes wait(), it's successful
            });
        });

        describe("addLiquidityETH", async () => {
            it("successfully adds liquidity to empty pool", async () => {
                const tx = await liquidity.addLiquidityETH(
                    wmatic.address,
                    toWei("100"),
                    toWei("100"),
                    toWei("100"),
                    accounts[0],
                    deadline,
                    {
                        value: toWei("100"),
                    }
                );

                await tx.wait();

                const _pairAddress = await factory.getPair(wmatic.address, weth.address);
                const pair = Pair.attach(_pairAddress);
                const reserves = await pair.getReserveBalances();

                expect(reserves[0]).to.equal(toWei("100"));
                expect(reserves[1]).to.equal(toWei("100"));
            });
        });
    });

    describe("DreamSwapPair", async () => {
        describe("getReserveBalances", async () => {
            it("Fetches correct balances", async () => {
                const balances = await pair.getReserveBalances();
                expect(balances[0]).to.equal(toWei("100"));
            });
        });
    });

    describe("DreamSwapRouter", async () => {
        before(async () => {
            await wmatic.approve(router.address, toWei("10000000000000000000000000"));
            await link.approve(router.address, toWei("10000000000000000000000000"));
            await weth.approve(router.address, toWei("10000000000000000000000000"));
        });
        describe("swapExactTokensForTokens", async () => {
            it("Successfully swaps using correct parameters", async () => {
                const amountIn = toWei("5");
                const path = [wmatic.address, link.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);

                const tx = await router.swapExactTokensForTokens(
                    amountIn,
                    amountsOutMin[1],
                    path,
                    accounts[0],
                    deadline
                );

                await tx.wait();
            });
        });

        describe("swapTokensForExactTokens", async () => {
            it("Successfully swaps using correct parameters", async () => {
                const amountOutDesired = toWei("5");

                const path = [wmatic.address, link.address];

                const amountsInMax = await router.getAmountsIn(amountOutDesired, path);

                const tx = await router.swapTokensForExactTokens(
                    amountOutDesired,
                    amountsInMax[0],
                    path,
                    accounts[0],
                    deadline
                );

                await tx.wait();
            });
        });

        describe("swapExactETHForTokens", async () => {
            //uint amountOutMin, address[] calldata path, address to, uint deadline
            it("Successfully swaps using correct parameters", async () => {
                const amountIn = toWei("5");

                const path = [weth.address, wmatic.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);

                console.log(amountsOutMin);

                const tx = await router.swapExactETHForTokens(
                    amountsOutMin[1],
                    path,
                    accounts[0],
                    deadline,
                    {
                        value: toWei("5"),
                    }
                );

                await tx.wait();
            });
        });
    });
});
