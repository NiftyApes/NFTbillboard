import { expect } from "chai";
import { ethers } from "hardhat";
import { AdFrame } from "../typechain-types";

describe("YourContract", function () {
  // We define a fixture to reuse the same setup in every test.

  let AdFrame: AdFrame;
  before(async () => {
    const [owner] = await ethers.getSigners();
    const yourContractFactory = await ethers.getContractFactory("AdFrame");
    AdFrame = (await yourContractFactory.deploy(owner.address)) as AdFrame;
    await AdFrame.waitForDeployment();
  });

  // describe("Deployment", function () {
  //   it("Should have the right message on deploy", async function () {
  //     expect(await AdFrame.greeting()).to.equal("Building Unstoppable Apps!!!");
  //   });

  //   it("Should allow setting a new message", async function () {
  //     const newGreeting = "Learn Scaffold-ETH 2! :)";

  //     await AdFrame.setGreeting(newGreeting);
  //     expect(await AdFrame.greeting()).to.equal(newGreeting);
  //   });
  // });
});
