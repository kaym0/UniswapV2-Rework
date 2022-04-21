import { ethers } from "ethers";
/*
/// The following commented code is specific to merkle tree testing. To enable, 
add the merkletreejs and keccak256 packages and uncommented this code.

import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

const abi = ethers.utils.defaultAbiCoder;

const generateTestList = (accounts: any) => {
  accounts.pop(0);
  const list: any[] = [];
  accounts.forEach((account: string) => {
    list.push({
      account: account,
      startAmount: ethers.utils.parseUnits("100", "18").toString(),
    });
  });

  return list;
};

const getMerkleRoot = (testList: any) => {
  try {
    const leafNodes = testList.map((item: any) =>
      ethers.utils.hexStripZeros(
        abi.encode(["address", "uint256"], [item.account, item.startAmount])
      )
    );
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });
    const root = merkleTree.getHexRoot();
    return {
      root,
    };
  } catch (error) {
    console.log("Account does not exist");
  }
};

const getMerkleData = (account: any, startAmount: any, testList: any) => {
  try {
    const accountData = testList.find((o: any) => o.account == account);
    const leafNodes = testList.map((item: any) =>
      ethers.utils.hexStripZeros(
        abi.encode(["address", "uint256"], [item.account, item.startAmount])
      )
    );
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });
    const root = merkleTree.getHexRoot();
    const leaf = keccak256(
      ethers.utils.hexStripZeros(
        abi.encode(["address", "uint256"], [account, startAmount])
      )
    );
    const proof = merkleTree.getHexProof(leaf);

    return {
      root,
      leaf,
      proof,
    };
  } catch (error) {
    console.log("Account does not exist");
  }
};
*/
export const advanceTime = (time: any, ethers: any) => {
  return new Promise(async (resolve: any, reject: any) => {
    await ethers.provider.send(
      "evm_increaseTime",
      [time]
    );
    resolve();
  });
};

export const advanceTimeAndBlock = async (time: any, ethers: any) => {
  await advanceTime(time, ethers);
  await advanceBlock(ethers);;
};


export const toWei = (amount: string | number) => {
  return ethers.utils.parseUnits(amount.toString(), "18");
};

export const fromWei = (amount: string | number) => {
  return ethers.utils.formatUnits(amount, "18");
};

export const advanceBlock = (ethers: any) => {
  return new Promise(async (resolve: any, reject: any) => {
    await ethers.provider.send("evm_mine");
    resolve();
  });
};
