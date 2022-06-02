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

    async function getAllBalances() {
        const addresses = [
            accounts[0],
            accounts[1],
            accounts[2],
            accounts[3],
            accounts[4],
            pair.address,
        ];

        const data: any = [];

        const fetchBalances = new Promise((resolve: any, reject) => {
            let resolved = 0;
            addresses.forEach(async (account, i) => {
                const u = await getBalances(account, "user" + i);
                data.push(u);
                resolved++;
                if (resolved == addresses.length) {
                    resolve();
                }
            });
        });

        await fetchBalances;

        console.table(data);
    }

    async function getBalances(address: string, name: string) {
        const wmaticBalance = await wmatic.balanceOf(address);
        const linkBalance = await link.balanceOf(address);
        const pairBalance = await pair.balanceOf(address);

        const data = {
            name: name,
            wmatic: fromWei(wmaticBalance),
            link: fromWei(linkBalance),
            lp: fromWei(pairBalance),
        };

        console.table(data);

        return data;
    }

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

        const Factory = await ethers.getContractFactory("ToknFactory");
        const Token = await ethers.getContractFactory("TestToken");
        const Weth = await ethers.getContractFactory("WETH");
        Pair = await ethers.getContractFactory("ToknPair");
        //Pair = await ethers.getContractFactory("DreamSwapPair", {
        //    libraries: {
        //        Math: mathlib.address,
        //    },
        //});
        const Router = await ethers.getContractFactory("ToknRouter");
        const Liquidity = await ethers.getContractFactory("ToknLiquidity");

        /// Get signers
        [..._accounts] = await ethers.getSigners();
        /// Map addresses for easy access
        accounts = _accounts.map((account: any) => account.address);

        /// Deploy test tokens
        wmatic = await deployToken("Wrapped Matic", "WMATIC", Token);
        link = await deployToken("ChainLink", "Link", Token);
        weth = await deployContract(Weth);

        /// Deploy infrastructure
        factory = await deployContract(Factory);
        pairImplementation = await deployContract(Pair);
        router = await deployContract(Router, [factory.address, weth.address]);
        liquidity = await deployContract(Liquidity, [factory.address, weth.address]);

        /*
        /// Sends ETH to fallback function
        const tx = await _accounts[9].sendTransaction({
            to: weth.address,
            value: ethers.utils.parseEther("99"), // Sends exactly 1.0 ether
        });
        */

        //await tx.wait();
        const wethEthBalance = await ethers.provider.getBalance(weth.address);
        console.log(fromWei(wethEthBalance.toString()));
        console.log("Router", router.address);
        console.log("User", accounts[0]);
        console.log("weth", weth.address);
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

            /*

            THIS IS FOR GETTING THE PROPER INIT CODE HASH
            it("Tests the salting", async () => {
                const saltA = await factory.computeAndSaltAddress(pairImplementation.address, wmatic.address, link.address);
                const saltB = await factory.computeAndSaltAddress(pairImplementation.address, link.address, wmatic.address);

                console.log(saltA);
                console.log(saltB);
            });
            */

            it("Correctly gets invalid pair as zero address", async () => {
                const pair = await factory.getPair(wmatic.address, weth.address);
                expect(pair).to.equal(zeroAddress);
            });
        });

        describe("allPairs", async () => {
            it("Fetches all currently available liquidity pairs", async () => {
                const pairs = await factory.allPairs();

                const _pair = await factory.getPair(wmatic.address, link.address);

                expect(pairs[0]).to.equal(_pair);
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
                    toWei("50"),
                    toWei("50"),
                    toWei("50"),
                    accounts[0],
                    deadline,
                    {
                        value: toWei("50"),
                    }
                );

                await tx.wait();

                const _pairAddress = await factory.getPair(wmatic.address, weth.address);
                const pair = Pair.attach(_pairAddress);
                const reserves = await pair.getReserveBalances();

                expect(reserves[0]).to.equal(toWei("50"));
                expect(reserves[1]).to.equal(toWei("50"));
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

        describe("token0", async () => {
            it("Returns correct address", async () => {
                const token0 = await pair.token0();
                expect(token0).to.equal(link.address);
            });
        });

        describe("token1", async () => {
            it("Returns correct address", async () => {
                const token1 = await pair.token1();
                expect(token1).to.equal(wmatic.address);
            });
        });

        describe("name0", async () => {
            it("Returns the correct name", async () => {
                const name0 = await pair.name0();
                expect(name0).to.equal("ChainLink");
            });
        });

        describe("name1", async () => {
            it("Returns the correct name", async () => {
                const name1 = await pair.name1();
                expect(name1).to.equal("Wrapped Matic");
            });
        });

        describe("symbol0", async () => {
            it("Returns the correct symbol", async () => {
                const symbol0 = await pair.symbol0();
                expect(symbol0).to.equal("Link");
            });
        });

        describe("symbol1", async () => {
            it("Returns the correct symbol", async () => {
                const symbol1 = await pair.symbol1();
                expect(symbol1).to.equal("WMATIC");
            });
        });

        describe("decimals0", async () => {
            it("Returns correct decimals", async () => {
                const decimals0 = await pair.decimals0();
                expect(decimals0).to.equal(18);
            });
        });

        describe("decimals1", async () => {
            it("Returns correct decimals", async () => {
                const decimals1 = await pair.decimals1();
                expect(decimals1).to.equal(18);
            });
        });

        describe("getBalances", async () => {
            it("Fetches balances", async () => {
                const balances = await pair.getBalances();
                const [balances0, balances1] = balances;

                expect(balances0).to.equal(toWei("100"));
                expect(balances1).to.equal(toWei("100"));
            });
        });

        describe("getReserves", async () => {
            it("Fetches reserve balances", async () => {
                const reserves = await pair.getReserveBalances();
                const [reserve0, reserve1] = reserves;

                expect(reserve0).to.equal(toWei("100"));
                expect(reserve1).to.equal(toWei("100"));
            });
        });
    });

    describe("DreamSwapRouter", async () => {
        before(async () => {
            await wmatic.approve(router.address, toWei("10000000000000000000000000"));
            await link.approve(router.address, toWei("10000000000000000000000000"));
            await weth.approve(router.address, toWei("10000000000000000000000000"));
            await pair.approve(router.address, toWei("10000000000000000000000000"));

            const ethBalanceRouter = await ethers.provider.getBalance(router.address);
            const wethBalanceRouter = await weth.balanceOf(router.address);

            console.log("ethBalanceRouter", ethBalanceRouter);
            console.log("wethBalanceRouter", wethBalanceRouter);
        });

        describe("getAmountsOut", async () => {
            it("Successfully gets a result", async () => {
                const amountIn = toWei("5");
                const path = [wmatic.address, link.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);
            });
        });

        describe("getAmountsIn", async () => {
            it("Successfully gets a result", async () => {
                const amountIn = toWei("5");
                const path = [wmatic.address, link.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);
            });
        });
        describe("swapExactTokensForTokens", async () => {
            it("Successfully swaps using correct parameters", async () => {
                const amountIn = toWei("5");
                const path = [wmatic.address, link.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);

                const pair = await factory.getPair(wmatic.address, link.address);

       
                await getBalances(accounts[0], "account0");
                await getBalances(pair, "account0");

                const tx = await router.swapExactTokensForTokens(
                    amountIn,
                    amountsOutMin[1],
                    path,
                    accounts[0],
                    deadline
                );

                await tx.wait();

                await getBalances(accounts[0], "account0");
                await getBalances(pair, "account0");
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

        // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        describe("swapTokensForExactETH", async () => {
            it("Successfully swaps using correct parameters", async () => {
                const amountOutDesired = toWei("5");

                const path = [wmatic.address, weth.address];

                const amountsInMax = await router.getAmountsIn(amountOutDesired, path);

                const tx = await router.swapTokensForExactETH(
                    amountOutDesired,
                    amountsInMax[0],
                    path,
                    accounts[0],
                    deadline
                );

                await tx.wait();
            });
        });

        describe("swapExactTokensForETH", async () => {
            it("Successfully swaps exact tokens for eth", async () => {
                const userEthBalanceA = await ethers.provider.getBalance(accounts[0]);
                const userWethBalanceA = await weth.balanceOf(accounts[0]);
                const amountIn = toWei("5");

                const path = [wmatic.address, weth.address];

                const amountsOutMin = await router.getAmountsOut(amountIn, path);

                const tx = await router.swapExactTokensForETH(
                    amountIn,
                    amountsOutMin[1],
                    path,
                    accounts[0],
                    deadline
                );

                await tx.wait();

            });
        });

        describe("swapETHForExactTokens", async () => {
            it("Successfully swaps exact tokens for eth", async () => {
                const amountInDesired = toWei("5");

                const path = [weth.address, wmatic.address];

                const amountsOutMin = await router.getAmountsOut(amountInDesired, path);

                const tx = await router.swapETHForExactTokens(
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

        describe("removeLiquidity", async () => {
            it("Removes liquidity", async () => {
                await pair.approve(liquidity.address, "100000000000000000000000000000000000000")

                await liquidity.removeLiquidity(
                    wmatic.address,
                    link.address,
                    toWei(5),
                    "0",
                    "0",
                    accounts[0],
                    deadline
                )
            })
        })


        describe("computeAndSaltAddress", async () => {
            it("Gets hashed creation code", async () => {
                const data = await factory.computeAndSaltAddress(pairImplementation.address, wmatic.address, link.address);
                console.log(data);
            })
        })
    });
});
