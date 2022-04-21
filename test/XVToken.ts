import { expect } from "chai";
import { ethers } from "hardhat";
import { advanceTimeAndBlock, fromWei, toWei } from "./functions";

describe("Main", function () {
  let xv: any;
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

  before(async () => {
    const XVToken = await ethers.getContractFactory("XVToken");
    [..._accounts] = await ethers.getSigners();

    accounts = _accounts.map((account: any) => account.address);
    xv = await XVToken.deploy(accounts[0]);
  });

  describe("balanceOf", async () => {
    it("Checks balance of owner", async () => {
      const balance = await xv.balanceOf(accounts[0]);
      console.log(balance);
    });
  });

  describe("getCompoudAMount", async () => {
    it("Should return the new greeting once it's changed", async function () {
      const amount = await xv._getCompoundAmount(toWei("1"));
      console.log(fromWei(amount));
    });

    it("After one week", async function () {
      await advance(26);
      const amount = await xv._getCompoundAmount(toWei("1"));
      console.log(fromWei(amount));
    });

    describe("balanceOf", async () => {
      it("Checks balance of owner", async () => {
        const balance = await xv.balanceOf(accounts[0]);
        console.log("balanceOf", balance);
      });
    });
    /*
    it("After one week", async function () {
      await advance(26);
      const amount = await xv._getCompoundAmount(toWei("1"));
      console.log(fromWei(amount));
    });

    it("After one week", async function () {
      await advance(85);
      const amount = await xv._getCompoundAmount(toWei("1"));
      console.log(fromWei(amount));
    });
    */
  });
});
